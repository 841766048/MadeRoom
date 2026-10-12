// Scoped, idempotent editorial seed. No emails, passwords or synthetic follows.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),project='made-room-20261009';
const emulator=process.argv.includes('--emulator'), publish=process.argv.includes('--publish');
const base=`${emulator?'http://127.0.0.1:8188':'https://firestore.googleapis.com'}/v1/projects/${project}/databases/(default)`;
const authBase=`${emulator?'http://127.0.0.1:9098/identitytoolkit.googleapis.com':'https://identitytoolkit.googleapis.com'}/v1/projects/${project}`;
function encode(v){if(v===null)return {nullValue:null};if(typeof v==='string')return {stringValue:v};if(typeof v==='boolean')return {booleanValue:v};if(typeof v==='number')return {integerValue:String(v)};if(Array.isArray(v))return {arrayValue:{values:v.map(encode)}};return {mapValue:{fields:Object.fromEntries(Object.entries(v).map(([k,v])=>[k,encode(v)]))}};}
async function main(){
 let token='owner';
 if(!emulator){const auth=require(path.join(process.env.FIREBASE_TOOLS_DIR,'lib/auth.js'));const account=auth.getGlobalDefaultAccount();assert.ok(account);token=(await auth.getAccessToken(account.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform'])).access_token;}
 async function request(url,body){let r=await fetch(url,{method:body?'POST':'GET',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});if(!r.ok)throw new Error(`Request failed ${r.status}: ${new URL(url).pathname}`);return r.json()}
 if(!emulator){const database=await request(base);assert.equal(database.freeTier,true);assert.equal(database.databaseEdition,'STANDARD');}
 const seed=JSON.parse(fs.readFileSync(path.join(root,'content/community-seed.json')));
 assert.equal(seed.creators.length,5);assert.equal(seed.posts.length,10);
 const ids=seed.creators.map(p=>p.uid);assert.equal(new Set(ids).size,5);
 const images=new Set(JSON.parse(fs.readFileSync(path.join(root,'content/image-manifest.json'))).images.map(i=>i.id??i.asset));
 for(const p of seed.creators){assert.match(p.uid,/^example-[a-z]+$/);assert.equal(p.isExample,true);assert.ok(images.has(p.avatarID));}
 for(const p of seed.posts){assert.ok(ids.includes(p.authorUID));assert.ok(images.has(p.imageID));assert.equal(p.language,'en');assert.equal(p.contentType,'editorial-example');}
 const existing=(await request(`${authBase}/accounts:lookup`,{localId:ids})).users??[];
 for(const p of existing){assert.equal(p.disabled,true,'Refusing to use an active account');assert.equal(p.displayName,seed.creators.find(c=>c.uid===p.localId).displayName);}
 if(publish){
  const missing=seed.creators.filter(p=>!existing.some(u=>u.localId===p.uid));
  if(missing.length){const result=await request(`${authBase}/accounts:batchCreate`,{users:missing.map(p=>({localId:p.uid,displayName:p.displayName,disabled:true})),allowOverwrite:false,sanityCheck:true});assert.ok(!result.error?.length,'Account import partially failed');}
 }
 const users=(await request(`${authBase}/accounts:lookup`,{localId:ids})).users??[];
 assert.equal(users.length,5);for(const u of users){assert.equal(u.disabled,true);assert.ok(!u.email);}
 const docs=[...seed.creators.map(p=>['publicProfiles',p.uid,p]),...seed.posts.map(p=>['communityPosts',p.id,p])].map(([collection,id,value])=>({name:`projects/${project}/databases/(default)/documents/${collection}/${id}`,fields:encode(value).mapValue.fields}));
 if(publish)await request(`${base}/documents:commit`,{writes:docs.map(update=>({update}))});
 for(const d of docs){const actual=await request(`${base}/documents/${d.name.split('/documents/')[1]}`);assert.deepEqual(actual.fields,d.fields);}
 console.log(JSON.stringify({project,emulator,mode:publish?'publish-and-verify':'verify',verifiedExampleAccounts:users.length,verifiedPublicProfiles:5,verifiedPosts:10,createdFollows:0},null,2));
}
main().catch(e=>{console.error(e.message);process.exitCode=1});
