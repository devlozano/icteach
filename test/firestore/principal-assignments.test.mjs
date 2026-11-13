import {after,before,beforeEach,test} from 'node:test';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,setDoc,updateDoc,writeBatch,getDoc} from 'firebase/firestore';
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-icteach-principal',firestore:{host:'127.0.0.1',port:8188,rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}})});
after(async()=>{await env?.cleanup()});
const user=id=>env.authenticatedContext(id).firestore();
const classroom=()=>({name:'CSS',sectionCode:'A',teacherId:'teacher',schoolYear:'2026-2027',status:'active',enrolledStudentIds:['student'],trainerIds:[],createdBy:'principal'});
beforeEach(async()=>{await env.clearFirestore();await env.withSecurityRulesDisabled(async c=>{
 for(const [id,role] of Object.entries({principal:'admin',teacher:'teacher',other:'teacher',trainer:'trainer',student:'student',outsider:'student'})) await setDoc(doc(c.firestore(),'users',id),{role,isActive:true});
 await setDoc(doc(c.firestore(),'classes/class'),classroom());
})});
test('only principal creates sections',async()=>{
 await assertSucceeds(setDoc(doc(user('principal'),'classes/new'),classroom()));
 for(const id of ['teacher','trainer','student']) await assertFails(setDoc(doc(user(id),'classes/new-'+id),{...classroom(),createdBy:id}));
});
test('teachers cannot reassign sections or trainers',async()=>{
 await assertFails(updateDoc(doc(user('teacher'),'classes/class'),{teacherId:'other'}));
 await assertFails(updateDoc(doc(user('teacher'),'classes/class'),{trainerIds:['trainer']}));
 await assertSucceeds(updateDoc(doc(user('principal'),'classes/class'),{teacherId:'other'}));
 await assertSucceeds(updateDoc(doc(user('principal'),'classes/class'),{trainerIds:['trainer']}));
});
test('trainer memberships are principal-only even for own account',async()=>{
 const data={classId:'class',teacherId:'teacher',role:'trainer'};
 await assertFails(setDoc(doc(user('trainer'),'users/trainer/classes/class'),data));
 await assertFails(setDoc(doc(user('teacher'),'users/trainer/classes/class'),data));
 await assertSucceeds(setDoc(doc(user('principal'),'users/trainer/classes/class'),data));
 await assertFails(updateDoc(doc(user('trainer'),'users/trainer/classes/class'),{teacherId:'other'}));
});
test('teacher roster and invited student memberships continue working',async()=>{
 await assertSucceeds(updateDoc(doc(user('teacher'),'classes/class'),{enrolledStudentIds:['student','outsider']}));
 await assertSucceeds(setDoc(doc(user('student'),'users/student/classes/class'),{classId:'class',teacherId:'teacher'}));
 await assertFails(setDoc(doc(user('outsider'),'users/student/classes/class'),{classId:'class',teacherId:'teacher'}));
});
test('unauthorized class participant access is blocked',async()=>{
 await assertFails(setDoc(doc(user('outsider'),'classes/class/modules/new'),{title:'Unassigned'}));
 await assertFails(setDoc(doc(user('student'),'classes/class/modules/new'),{title:'Student edit'}));
 await assertFails(setDoc(doc(user('principal'),'classes/class/modules/principal-module'),{title:'Principal module'}));
 await assertFails(setDoc(doc(user('principal'),'classes/class/quizzes/principal-quiz'),{title:'Principal quiz'}));
 await assertFails(setDoc(doc(user('principal'),'classes/class/assignments/principal-assignment'),{title:'Principal assignment'}));
 await assertSucceeds(setDoc(doc(user('teacher'),'classes/class/modules/new'),{title:'Lesson'}));
 await assertFails(getDoc(doc(user('trainer'),'classes/class/modules/new')));
 await assertSucceeds(updateDoc(doc(user('principal'),'classes/class'),{trainerIds:['trainer']}));
 await assertSucceeds(getDoc(doc(user('trainer'),'classes/class/modules/new')));
 await assertSucceeds(setDoc(doc(user('trainer'),'classes/class/modules/trainer-module'),{title:'Trainer lesson'}));
});
test('students can only write their own module access record',async()=>{
 await assertSucceeds(setDoc(doc(user('student'),'classes/class/module_access/module_student'),{studentId:'student',moduleId:'module'}));
 await assertFails(setDoc(doc(user('student'),'classes/class/module_access/module_other'),{studentId:'outsider',moduleId:'module'}));
});
test('invalid principal class data is rejected',async()=>{
 await assertFails(setDoc(doc(user('principal'),'classes/bad'),{...classroom(),teacherId:'student'}));
 await assertFails(updateDoc(doc(user('principal'),'classes/class'),{sectionCode:''}));
 await assertFails(updateDoc(doc(user('principal'),'classes/class'),{trainerIds:'trainer'}));
});
test('self profile cannot grant principal role or reactivate an account',async()=>{
 await assertFails(updateDoc(doc(user('teacher'),'users/teacher'),{role:'admin'}));
 await assertFails(updateDoc(doc(user('teacher'),'users/teacher'),{isActive:false}));
});
