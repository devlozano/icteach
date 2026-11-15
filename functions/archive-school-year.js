'use strict';

const TIME_ZONE = 'Asia/Manila';
const SCHOOL_YEAR_START_MONTH = 6;
const MAX_BATCH_OPERATIONS = 400;

function parseSchoolYear(value) {
  const match = /^(\d{4})-(\d{4})$/.exec(String(value || '').trim());
  if (!match) return null;
  const startYear = Number(match[1]);
  const endYear = Number(match[2]);
  if (endYear !== startYear + 1) return null;
  return {name: `${startYear}-${endYear}`, startYear, endYear};
}

function schoolYearForDate(date, timeZone = TIME_ZONE) {
  const parts = Object.fromEntries(
      new Intl.DateTimeFormat('en-US', {
        timeZone,
        year: 'numeric',
        month: 'numeric',
        day: 'numeric',
      }).formatToParts(date)
          .filter((part) => part.type !== 'literal')
          .map((part) => [part.type, Number(part.value)]),
  );
  const startYear = parts.month >= SCHOOL_YEAR_START_MONTH ?
    parts.year : parts.year - 1;
  return {
    name: `${startYear}-${startYear + 1}`,
    startYear,
    endYear: startYear + 1,
  };
}

function chunks(items, size) {
  const result = [];
  for (let index = 0; index < items.length; index += size) {
    result.push(items.slice(index, index + size));
  }
  return result;
}

function makeArchiveSchoolYearHandler({db, fieldValue, now = () => new Date()}) {
  return async () => {
    const current = schoolYearForDate(now());
    const settingsRef = db.collection('system_settings').doc('academic_year');
    const settingsSnapshot = await settingsRef.get();
    const configured = parseSchoolYear(
        settingsSnapshot.exists ? settingsSnapshot.data().activeSchoolYear : null,
    );

    if (configured && configured.startYear > current.startYear) {
      return {
        status: 'future_school_year_configured',
        activeSchoolYear: configured.name,
        calendarSchoolYear: current.name,
        archivedClasses: 0,
      };
    }

    const classSnapshot = await db.collection('classes').get();
    const groups = new Map();
    for (const classDocument of classSnapshot.docs) {
      const data = classDocument.data();
      const classSchoolYear = parseSchoolYear(data.schoolYear);
      if (!classSchoolYear || classSchoolYear.startYear >= current.startYear) {
        continue;
      }
      if (!groups.has(classSchoolYear.name)) groups.set(classSchoolYear.name, []);
      groups.get(classSchoolYear.name).push({document: classDocument, data});
    }

    let archivedClasses = 0;
    for (const [schoolYear, classRecords] of groups.entries()) {
      for (const classChunk of chunks(classRecords, MAX_BATCH_OPERATIONS / 2)) {
        const batch = db.batch();
        for (const {document, data} of classChunk) {
          const archivedAt = data.archivedAt || fieldValue.serverTimestamp();
          if (data.status !== 'archived') {
            batch.update(document.ref, {
              status: 'archived',
              archivedAt,
              archiveSchoolYear: schoolYear,
              archiveReason: 'Automatic school year rollover',
            });
            archivedClasses += 1;
          }
          const archiveClassRef = db.collection('school_year_archives')
              .doc(schoolYear).collection('classes').doc(document.id);
          batch.set(archiveClassRef, {
            classId: document.id,
            className: data.className || data.name || 'Class',
            sectionCode: data.sectionCode || data.section || '',
            teacherId: data.teacherId || '',
            teacherName: data.teacherName || '',
            schoolYear,
            sourcePath: document.ref.path,
            archivedAt,
            dataPreservedInSource: true,
          }, {merge: true});
        }
        await batch.commit();
      }
      await db.collection('school_year_archives').doc(schoolYear).set({
        name: schoolYear,
        schoolYear,
        status: 'archived',
        classCount: classRecords.length,
        dataLocation: 'classes and their nested subcollections',
        dataPreservedInSource: true,
        updatedAt: fieldValue.serverTimestamp(),
      }, {merge: true});
    }

    const settingsUpdate = {
      activeSchoolYear: current.name,
      lastAutomaticArchiveCheckAt: fieldValue.serverTimestamp(),
    };
    if (!configured || configured.startYear < current.startYear) {
      settingsUpdate.previousSchoolYear = configured ? configured.name : null;
      settingsUpdate.lastRolloverAt = fieldValue.serverTimestamp();
      settingsUpdate.lastRolloverSource = 'scheduled';
    }
    await settingsRef.set(settingsUpdate, {merge: true});

    return {
      status: 'completed',
      activeSchoolYear: current.name,
      archiveNames: [...groups.keys()].sort(),
      archivedClasses,
      indexedClasses: [...groups.values()]
          .reduce((total, records) => total + records.length, 0),
    };
  };
}

module.exports = {
  TIME_ZONE,
  parseSchoolYear,
  schoolYearForDate,
  makeArchiveSchoolYearHandler,
};
