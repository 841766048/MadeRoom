import {readFile} from 'node:fs/promises';
import {before,after,beforeEach,test} from 'node:test';
import assert from 'node:assert/strict';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,getDocs,collection,query,orderBy,where,limit,updateDoc,deleteDoc,serverTimestamp,Timestamp,Bytes,runTransaction,onSnapshot} from 'firebase/firestore';
let env;
const projectId='made-room-20261009';
const path='knowledge/woven-reading-corner/comments';
const data=(extra={})=>({knowledgeID:'woven-reading-corner',authorUID:'alice',authorName:'Alice',text:'A useful weaving tip.',parentID:null,replyTo:null,createdAt:serverTimestamp(),...extra});
const db=(uid)=>uid?env.authenticatedContext(uid).firestore():env.unauthenticatedContext().firestore();
before(async()=>{env=await initializeTestEnvironment({projectId,firestore:{host:'127.0.0.1',port:8188,rules:await readFile(new URL('../../firestore.rules',import.meta.url),'utf8')}})});
beforeEach(async()=>{await env.clearFirestore()});
after(async()=>{await env.cleanup()});
test('author can create; another signed-in reader can read',async()=>{await assertSucceeds(setDoc(doc(db('alice'),path,'one'),data()));await assertSucceeds(getDoc(doc(db('bob'),path,'one')))});
test('unauthenticated get and create are denied',async()=>{await assertFails(getDoc(doc(db(),path,'one')));await assertFails(setDoc(doc(db(),path,'one'),data()))});
test('UID spoofing is denied',async()=>assertFails(setDoc(doc(db('bob'),path,'one'),data())));
test('unknown knowledge and mismatched IDs are denied',async()=>{await assertFails(setDoc(doc(db('alice'),'knowledge/unknown/comments/one'),data({knowledgeID:'unknown'})));await assertFails(setDoc(doc(db('alice'),path,'one'),data({knowledgeID:'clay-catchall'})))});
for(const [name,patch] of [
 ['oversized text',{text:'x'.repeat(2001)}],['empty text',{text:''}],['wrong text type',{text:3}],
 ['oversized name',{authorName:'x'.repeat(81)}],['empty name',{authorName:''}],['oversized reply name',{replyTo:'x'.repeat(81)}],
 ['forged timestamp',{createdAt:Timestamp.fromMillis(0)}],['extra admin field',{isAdmin:true}],
 ['cross-path parent',{parentID:'other/parent'}],['missing parent',{parentID:'absent'}]
]) test(name+' is denied',async()=>assertFails(setDoc(doc(db('alice'),path,'one'),data(patch))));
test('required field omission is denied',async()=>{let d=data();delete d.authorUID;await assertFails(setDoc(doc(db('alice'),path,'one'),d))});
test('body, ownership and timestamp edits and deletion are denied',async()=>{let ref=doc(db('alice'),path,'one');await setDoc(ref,data());for(const patch of [{text:'changed'},{authorUID:'bob'},{createdAt:serverTimestamp()}]) await assertFails(updateDoc(ref,patch));await assertFails(deleteDoc(ref));await assertFails(updateDoc(doc(db('bob'),path,'one'),{text:'hijack'}))});
test('bounded ordered query succeeds; unlimited and oversized queries fail',async()=>{let c=collection(db('alice'),path);await assertSucceeds(getDocs(query(c,orderBy('createdAt','desc'),limit(50))));await assertFails(getDocs(c));await assertFails(getDocs(query(c,limit(51))))});
test('real root replies and seed-root replies succeed; nested replies fail',async()=>{let a=db('alice');await setDoc(doc(a,path,'root'),data());await assertSucceeds(setDoc(doc(a,path,'reply'),data({parentID:'root',replyTo:'Alice'})));await assertSucceeds(setDoc(doc(a,path,'seedreply'),data({parentID:'tessa',replyTo:'Tessa'})));await assertFails(setDoc(doc(a,path,'nested'),data({parentID:'reply'})))});
test('retry transaction retains one ID and original timestamp',async()=>{let a=db('alice'),ref=doc(a,path,'stable');const submit=()=>runTransaction(a,async t=>{let old=await t.get(ref);if(!old.exists())t.set(ref,data())});await submit();let first=(await getDoc(ref)).data().createdAt;await submit();assert.equal((await getDocs(query(collection(a,path),limit(50)))).size,1);assert.ok(first.isEqual((await getDoc(ref)).data().createdAt))});
test('second reader receives live event',async()=>{let resolve,reject;const done=new Promise((a,b)=>{resolve=a;reject=b});let stop=onSnapshot(query(collection(db('bob'),path),orderBy('createdAt','desc'),limit(50)),snapshot=>{if(snapshot.docs.some(d=>d.id==='live'))resolve()},reject);let timer=setTimeout(()=>reject(new Error('No live snapshot')),10000);try{await setDoc(doc(db('alice'),path,'live'),data());await done}finally{clearTimeout(timer);stop()}});
test('private paths and writes outside comments remain denied',async()=>{await assertFails(getDoc(doc(db('alice'),'users','bob')));await assertFails(setDoc(doc(db('alice'),'users','alice'),{admin:true}))});

// Knowledge documents are trusted editorial content, never user-authored writes.
test('knowledge requires login and bounded queries; clients cannot publish or mutate', async()=>{
 const path='knowledge/weaving-even-edges';
 await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),path),{id:'weaving-even-edges',title:'Even edges',catalogOrder:0}));
 await assertFails(getDoc(doc(db(),path)));
 await assertSucceeds(getDoc(doc(db('alice'),path)));
 await assertSucceeds(getDocs(query(collection(db('alice'),'knowledge'),orderBy('catalogOrder'),limit(100))));
 await assertFails(getDocs(collection(db('alice'),'knowledge')));
 await assertFails(getDocs(query(collection(db('alice'),'knowledge'),limit(101))));
 await assertFails(setDoc(doc(db('alice'),'knowledge/new-article'),{title:'Fake'}));
 await assertFails(updateDoc(doc(db('alice'),path),{title:'Changed'}));
 await assertFails(deleteDoc(doc(db('alice'),path)));
});

test('all published knowledge IDs accept authenticated comments',async()=>{
 const groups=await Promise.all(['knowledge-existing','knowledge-new'].map(async name=>JSON.parse(await readFile(new URL(`../../content/${name}.json`,import.meta.url),'utf8'))));
 const items=groups.flatMap(g=>g.items);
 assert.equal(new Set(items.map(i=>i.id)).size,items.length);
 for(const item of items){
  await assertSucceeds(setDoc(doc(db('alice'),`knowledge/${item.id}/comments/catalog-check`),data({knowledgeID:item.id})));
 }
});

const profile=(extra={})=>({uid:'alice',displayName:'Alice',username:'alice.makes',biography:'Weaving slowly.',location:'Portland',avatar:null,revision:'revision-1',updatedAt:serverTimestamp(),...extra});
test('private profile can be created, restored and edited by its owner only',async()=>{
 const ref=doc(db('alice'),'users/alice');
 await assertSucceeds(setDoc(ref,profile()));
 assert.equal((await getDoc(ref)).data().location,'Portland');
 await assertSucceeds(setDoc(ref,profile({displayName:'New name',avatar:Bytes.fromUint8Array(new Uint8Array([255,216,255]))})));
 await assertFails(getDoc(doc(db('bob'),'users/alice')));
 await assertFails(getDoc(doc(db(),'users/alice')));
 await assertFails(setDoc(doc(db('bob'),'users/alice'),profile()));
 await assertFails(setDoc(doc(db(),'users/alice'),profile()));
 await assertFails(getDocs(collection(db('alice'),'users')));
 await assertFails(deleteDoc(ref));
});
test('profile rejects invalid fields, oversized photos and spoofed identity',async()=>{
 const ref=doc(db('alice'),'users/alice');
 for(const patch of [{uid:'bob'},{displayName:''},{displayName:'   '},{displayName:'x'.repeat(81)},
  {username:'no spaces'},{biography:'x'.repeat(501)},{location:'x'.repeat(121)},
  {avatar:'https://example.com/private.jpg'},{avatar:Bytes.fromUint8Array(new Uint8Array(98305))},
  {revision:''},{updatedAt:Timestamp.fromMillis(0)},{admin:true}]) {
  await assertFails(setDoc(ref,profile(patch)));
 }
 const missing=profile();delete missing.location;await assertFails(setDoc(ref,missing));
});

const spaceData=(extra={})=>({uid:'alice',name:'Reading nook',notes:'My handmade corner',piecesJSON:'[]',planJSON:'{}',beforePhoto:null,afterPhoto:null,deleted:false,revision:'rev-1',updatedAt:serverTimestamp(),...extra});
test('spaces are private to their owner, including list',async()=>{
 const a=db('alice'),b=db('bob'),path='users/alice/spaces/one';
 await assertSucceeds(setDoc(doc(a,path),spaceData()));
 await assertSucceeds(getDoc(doc(a,path)));await assertSucceeds(getDocs(collection(a,'users/alice/spaces')));
 await assertFails(getDoc(doc(b,path)));await assertFails(getDoc(doc(db(),path)));
 await assertFails(getDocs(collection(b,'users/alice/spaces')));await assertFails(setDoc(doc(b,path),spaceData()));
});
test('space changes, photos and tombstones round-trip',async()=>{
 const a=db('alice'),ref=doc(a,'users/alice/spaces/one');
 await assertSucceeds(setDoc(ref,spaceData({beforePhoto:Bytes.fromUint8Array(new Uint8Array([1,2,3]))})));
 await assertSucceeds(setDoc(ref,spaceData({name:'Renamed',deleted:true,revision:'rev-2'})));
 assert.equal((await getDoc(ref)).data().deleted,true);await assertFails(deleteDoc(ref));
});
for(const [name,patch] of [['spoofed owner',{uid:'bob'}],['long name',{name:'x'.repeat(81)}],['empty name',{name:''}],['long notes',{notes:'x'.repeat(4001)}],['oversized image',{afterPhoto:Bytes.fromUint8Array(new Uint8Array(196609))}],['wrong image type',{beforePhoto:'public-url'}],['forged time',{updatedAt:Timestamp.fromMillis(0)}],['extra field',{admin:true}]]) {
 test('space rejects '+name,async()=>assertFails(setDoc(doc(db('alice'),'users/alice/spaces/one'),spaceData(patch))));
}

const membership = (circleID='weaving', extra={}) => ({uid:'alice',circleID,joined:true,updatedAt:serverTimestamp(),...extra});
test('circle memberships persist join and leave; accounts and circles stay independent',async()=>{
 const a=db('alice'),ref=doc(a,'users/alice/circles/weaving');
 const change=joined=>runTransaction(a,async tx=>{await tx.get(ref);tx.set(ref,membership('weaving',{joined}))});
 await assertSucceeds(change(true));
 assert.equal((await getDoc(doc(db('alice'),'users/alice/circles/weaving'))).data().joined,true);
 await assertSucceeds(setDoc(doc(a,'users/alice/circles/craft'),membership('craft')));
 await assertSucceeds(change(false));
 assert.equal((await getDoc(ref)).data().joined,false);
 assert.equal((await getDoc(doc(a,'users/alice/circles/craft'))).data().joined,true);
 await assertSucceeds(getDocs(query(collection(a,'users/alice/circles'),limit(10))));
 await assertFails(getDocs(collection(a,'users/alice/circles')));
 await assertFails(getDoc(doc(db('bob'),'users/alice/circles/weaving')));
 await assertFails(getDoc(doc(db(),'users/alice/circles/weaving')));
 await assertFails(setDoc(doc(db('bob'),'users/alice/circles/weaving'),membership()));
 await assertFails(setDoc(doc(db(),'users/alice/circles/weaving'),membership()));
 await assertFails(deleteDoc(ref));
});
test('circle memberships reject forged IDs timestamps types and unexpected fields',async()=>{
 const a=db('alice'),ref=doc(a,'users/alice/circles/weaving');
 for(const patch of [{uid:'bob'},{circleID:'craft'},{joined:'yes'},{updatedAt:Timestamp.fromMillis(0)},{role:'admin'}]) await assertFails(setDoc(ref,membership('weaving',patch)));
 await assertFails(setDoc(doc(a,'users/alice/circles/unknown'),membership('unknown')));
 const missing=membership();delete missing.joined;await assertFails(setDoc(ref,missing));
 await assertSucceeds(setDoc(ref,membership()));
 await assertFails(updateDoc(ref,{uid:'bob',updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(ref,{role:'admin',updatedAt:serverTimestamp()}));
});

// Social data never borrows the old bundled popularity numbers.
const publicPerson=(uid)=>({uid,displayName:uid,biography:'',avatarID:'studio',isExample:false});
const edge=(a,b)=>({followerUID:a,followingUID:b,createdAt:serverTimestamp()});
async function people(){for(const uid of ['alice','bob'])await setDoc(doc(db(uid),'publicProfiles',uid),publicPerson(uid));}
test('new accounts have zero real relationships; follow survives a new client and unfollow removes it',async()=>{
 await people(); const a=db('alice'); const ref=doc(a,'socialFollows','alice:bob');
 assert.equal((await getDocs(collection(a,'socialFollows'))).size,0);
 await assertSucceeds(setDoc(ref,edge('alice','bob')));
 assert.equal((await getDocs(collection(db('bob'),'socialFollows'))).size,1);
 await assertFails(setDoc(ref,edge('alice','bob'))); // duplicates cannot rewrite original timestamp
 await assertFails(deleteDoc(doc(db('bob'),'socialFollows','alice:bob')));
 await assertSucceeds(deleteDoc(ref));assert.equal((await getDocs(collection(a,'socialFollows'))).size,0);
});
test('follow rejects self, missing target, impersonation and forged fields',async()=>{
 await people();for(const [id,value] of [['alice:alice',edge('alice','alice')],['alice:missing',edge('alice','missing')],['bob:alice',edge('bob','alice')],['wrong',edge('alice','bob')],['alice:bob',{...edge('alice','bob'),followers:99}],['alice:bob',{...edge('alice','bob'),createdAt:Timestamp.fromMillis(0)}]])await assertFails(setDoc(doc(db('alice'),'socialFollows',id),value));
 await assertFails(getDocs(collection(db(),'socialFollows')));
});
test('public profiles expose only approved fields and example identities cannot be client-created',async()=>{
 await people();await assertSucceeds(getDoc(doc(db('bob'),'publicProfiles','alice')));
 await assertFails(updateDoc(doc(db('bob'),'publicProfiles','alice'),{displayName:'Fake'}));
 for(const patch of [{email:'private@example.com'},{location:'private'},{isExample:true}])await assertFails(updateDoc(doc(db('alice'),'publicProfiles','alice'),patch));
 await assertFails(getDoc(doc(db(),'publicProfiles','alice')));
 await assertFails(getDoc(doc(db('bob'),'users','alice')));
});
test('community content is authenticated, bounded and only published by trusted tooling',async()=>{
 await assertSucceeds(getDocs(query(collection(db('alice'),'communityPosts'),limit(100))));
 await assertFails(getDocs(collection(db('alice'),'communityPosts')));
 await assertFails(getDocs(query(collection(db(),'communityPosts'),limit(100))));
 await assertFails(setDoc(doc(db('alice'),'communityPosts','fake'),{authorUID:'bob'}));
});


const memberPost=(extra={})=>({id:'post-one',authorUID:'alice',authorName:'alice',title:'My weave',body:'A real handmade piece.',photoData:null,visibility:'public',createdAt:serverTimestamp(),...extra});
test('member posts publish publicly; private posts remain owner-only',async()=>{
 await people();const a=db('alice'),b=db('bob');
 await assertSucceeds(setDoc(doc(a,'memberPosts','post-one'),memberPost()));
 await assertSucceeds(getDoc(doc(b,'memberPosts','post-one')));
 await assertSucceeds(setDoc(doc(a,'memberPosts','private-one'),memberPost({id:'private-one',visibility:'private',body:'First line\nSecond line'})));
 await assertFails(getDoc(doc(b,'memberPosts','private-one')));
 await assertSucceeds(getDocs(query(collection(b,'memberPosts'),where('visibility','==','public'),orderBy('createdAt','desc'),limit(50))));
 await assertSucceeds(getDocs(query(collection(a,'memberPosts'),where('authorUID','==','alice'),orderBy('createdAt','desc'),limit(50))));
 await assertFails(getDocs(query(collection(b,'memberPosts'),where('authorUID','==','alice'),limit(50))));
 await assertFails(getDocs(query(collection(b,'memberPosts'),limit(50))));
 await assertFails(getDoc(doc(db(),'memberPosts','post-one')));
});
test('member post rules reject forged author, malformed content and oversized images',async()=>{
 await people();for(const patch of [{authorUID:'bob'},{authorName:'Nora'},{id:'wrong'},{title:''},{title:' '.repeat(3)},{title:'x'.repeat(121)},{body:'x'.repeat(4001)},{photoData:'not bytes'},{photoData:Bytes.fromUint8Array(new Uint8Array(196609))},{visibility:'hidden'},{createdAt:Timestamp.fromMillis(1)},{isExample:true}])await assertFails(setDoc(doc(db('alice'),'memberPosts','post-one'),memberPost(patch)));
 await assertSucceeds(setDoc(doc(db('alice'),'memberPosts','post-one'),memberPost({photoData:Bytes.fromUint8Array(new Uint8Array([1,2,3]))})));
 await assertFails(updateDoc(doc(db('alice'),'memberPosts','post-one'),{visibility:'private'}));
 await assertFails(deleteDoc(doc(db('bob'),'memberPosts','post-one')));
 await assertSucceeds(deleteDoc(doc(db('alice'),'memberPosts','post-one')));
});
test('publication transaction retry preserves one document and original time',async()=>{
 await people();const a=db('alice'),ref=doc(a,'memberPosts','post-one');
 const publish=()=>runTransaction(a,async tx=>{const old=await tx.get(ref);if(!old.exists())tx.set(ref,memberPost())});
 await publish();const first=(await getDoc(ref)).data().createdAt;await publish();
 const docs=await getDocs(query(collection(a,'memberPosts'),where('authorUID','==','alice'),limit(50)));
 assert.equal(docs.size,1);assert.ok(first.isEqual(docs.docs[0].data().createdAt));
});

test('community discussion is isolated, live and requires an existing visible post',async()=>{
 await env.withSecurityRulesDisabled(async c=>{
  await setDoc(doc(c.firestore(),'communityPosts/example-one'),{title:'Example',authorUID:'alice'});
  await setDoc(doc(c.firestore(),'memberPosts/private-one'),{authorUID:'alice',visibility:'private'});
  await setDoc(doc(c.firestore(),'memberPosts/public-one'),{authorUID:'alice',visibility:'public'});
 });
 const a=db('alice'),b=db('bob');
 for(const id of ['community:example-one','member:public-one','member:private-one']) {
  const p=`knowledge/${id}/comments`;
  await assertSucceeds(setDoc(doc(a,p,'root'),data({knowledgeID:id,text:'First line\nSecond line'})));
  await assertSucceeds(setDoc(doc(a,p,'reply'),data({knowledgeID:id,parentID:'root',replyTo:'Alice'})));
  if(id==='member:private-one') {
   await assertFails(getDoc(doc(b,p,'root')));
   await assertFails(getDocs(query(collection(b,p),limit(50))));
   await assertFails(setDoc(doc(b,p,'other'),data({knowledgeID:id,authorUID:'bob'})));
  } else {
   await assertSucceeds(getDocs(query(collection(b,p),orderBy('createdAt','desc'),limit(50))));
  }
  await assertFails(setDoc(doc(a,p,'seed'),data({knowledgeID:id,parentID:'tessa'})));
 }
 await assertFails(setDoc(doc(a,'knowledge/community:absent/comments/root'),data({knowledgeID:'community:absent'})));
 await env.withSecurityRulesDisabled(async c=>deleteDoc(doc(c.firestore(),'memberPosts/public-one')));
 await assertFails(getDoc(doc(a,'knowledge/member:public-one/comments/root')));
 await assertFails(setDoc(doc(a,'knowledge/member:public-one/comments/new'),data({knowledgeID:'member:public-one'})));
});

test('library records and photos are private and reject oversized data',async()=>{
 const value={uid:'alice',kind:'project',payload:'{}',photo:null,deleted:false,revision:'v1',updatedAt:serverTimestamp()};
 const ref=doc(db('alice'),'users/alice/library/project-one');
 await assertSucceeds(setDoc(ref,value));await assertSucceeds(getDoc(ref));
 await assertFails(getDoc(doc(db('bob'),'users/alice/library/project-one')));
 await assertFails(setDoc(doc(db('bob'),'users/alice/library/project-two'),value));
 await assertFails(setDoc(ref,{...value,kind:'admin'}));
 await assertFails(setDoc(ref,{...value,photo:Bytes.fromUint8Array(new Uint8Array(196609))}));
 await assertSucceeds(setDoc(ref,{...value,deleted:true,revision:'v2'}));
});

const event=(kind,sourcePath,recipientUID='bob')=>({actorUID:'alice',recipientUID,kind,sourcePath,createdAt:serverTimestamp(),read:false});
const eventID=(kind,path,recipient='bob')=>kind+':'+path.replaceAll('/','~')+':'+recipient;
test('reactions are shared, idempotent and enforce ownership, privacy and blocking',async()=>{
 await people();await env.withSecurityRulesDisabled(async c=>{
  await setDoc(doc(c.firestore(),'communityPosts/one'),{authorUID:'bob'});
  await setDoc(doc(c.firestore(),'memberPosts/private'),{authorUID:'bob',visibility:'private'});
 });
 const a=db('alice'),b=db('bob'),path='communityPosts/one/likes/alice';
 await assertSucceeds(setDoc(doc(a,path),{authorUID:'alice',createdAt:serverTimestamp()}));
 assert.equal((await getDocs(collection(b,'communityPosts/one/likes'))).size,1);
 await assertFails(setDoc(doc(b,path),{authorUID:'alice',createdAt:serverTimestamp()}));
 await assertFails(setDoc(doc(a,'memberPosts/private/likes/alice'),{authorUID:'alice',createdAt:serverTimestamp()}));
 await assertSucceeds(deleteDoc(doc(a,path)));
 await assertSucceeds(setDoc(doc(b,'users/bob/blocks/alice'),{uid:'bob',targetUID:'alice',active:true,updatedAt:serverTimestamp()}));
 await assertFails(setDoc(doc(a,path),{authorUID:'alice',createdAt:serverTimestamp()}));
 await assertFails(setDoc(doc(a,'socialFollows/alice:bob'),{followerUID:'alice',followingUID:'bob',createdAt:serverTimestamp()}));
 await assertFails(getDoc(doc(a,'users/bob/blocks/alice')));
});
test('inbox events require an atomic real source and recipient alone can mark read',async()=>{
 await people();await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'communityPosts/one'),{authorUID:'bob'}));
 const a=db('alice'),b=db('bob'),path='communityPosts/one/likes/alice',id=eventID('like',path);
 await assertFails(setDoc(doc(a,'users/bob/inbox/'+id),event('like',path)));
 await assertSucceeds(runTransaction(a,async tx=>{tx.set(doc(a,path),{authorUID:'alice',createdAt:serverTimestamp()});tx.set(doc(a,'users/bob/inbox/'+id),event('like',path));}));
 await assertSucceeds(getDoc(doc(b,'users/bob/inbox/'+id)));
 await assertFails(getDoc(doc(a,'users/bob/inbox/'+id)));
 await assertSucceeds(updateDoc(doc(b,'users/bob/inbox/'+id),{read:true}));
 await assertFails(updateDoc(doc(b,'users/bob/inbox/'+id),{actorUID:'bob'}));
 await assertFails(setDoc(doc(a,'users/alice/inbox/'+eventID('like',path,'alice')),event('like',path,'alice')));
});
test('follow and comment events validate the actual recipient',async()=>{
 await people();await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'communityPosts/one'),{authorUID:'bob'}));
 const a=db('alice'),follow='socialFollows/alice:bob';
 await assertSucceeds(runTransaction(a,async tx=>{tx.set(doc(a,follow),{followerUID:'alice',followingUID:'bob',createdAt:serverTimestamp()});tx.set(doc(a,'users/bob/inbox/'+eventID('follow',follow)),event('follow',follow));}));
 const path='knowledge/community:one/comments/comment1';
 await assertSucceeds(runTransaction(a,async tx=>{tx.set(doc(a,path),data({knowledgeID:'community:one'}));tx.set(doc(a,'users/bob/inbox/'+eventID('comment',path)),event('comment',path));}));
 await assertFails(setDoc(doc(a,'users/alice/inbox/'+eventID('comment',path,'alice')),event('comment',path,'alice')));
});
test('reports persist privately and users cannot approve or forge them',async()=>{
 await people();const a=db('alice'),b=db('bob');
 const report={reporterUID:'alice',targetPath:'publicProfiles/bob',reason:'Other',details:'Please review',kind:'report',status:'submitted',createdAt:serverTimestamp()};
 await assertSucceeds(setDoc(doc(a,'reports/one'),report));
 await assertSucceeds(getDocs(query(collection(a,'reports'),where('reporterUID','==','alice'),limit(50))));
 await assertFails(getDoc(doc(b,'reports/one')));await assertFails(updateDoc(doc(a,'reports/one'),{status:'approved'}));
 await assertFails(setDoc(doc(a,'reports/two'),{...report,targetPath:'publicProfiles/missing'}));
 await assertFails(setDoc(doc(b,'reports/two'),report));
 await assertFails(setDoc(doc(a,'reports/appeal'),{...report,kind:'appeal'}));
});
test('challenge submissions require membership and own project and can be withdrawn',async()=>{
 const a=db('alice'),b=db('bob');
 const submission={uid:'alice',challengeID:'one-shelf',projectID:'project1',title:'My make',caption:'Done',photo:null,status:'submitted',createdAt:serverTimestamp(),updatedAt:serverTimestamp()};
 await assertFails(setDoc(doc(a,'challenges/one-shelf/submissions/alice'),submission));
 await setDoc(doc(a,'users/alice/challenges/one-shelf'),{uid:'alice',joined:true,updatedAt:serverTimestamp()});
 await setDoc(doc(a,'users/alice/library/project-project1'),{uid:'alice',kind:'project',payload:'{}',photo:null,deleted:false,revision:'1',updatedAt:serverTimestamp()});
 await assertSucceeds(setDoc(doc(a,'challenges/one-shelf/submissions/alice'),submission));
 await assertSucceeds(updateDoc(doc(a,'challenges/one-shelf/submissions/alice'),{status:'withdrawn',updatedAt:serverTimestamp()}));
 await assertFails(getDoc(doc(b,'challenges/one-shelf/submissions/alice')));
 await assertFails(setDoc(doc(b,'challenges/one-shelf/submissions/alice'),submission));
});
