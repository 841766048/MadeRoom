// Usage: FIREBASE_TOOLS_DIR=/path/to/node_modules/firebase-tools node tools/publish_knowledge.cjs [--verify-only]
// Uses the Firebase CLI's signed-in account in memory; never writes credentials.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const project = 'made-room-20261009';
const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)`;
function encode(v) {
 if (v === null) return {nullValue:null};
 if (typeof v === 'string') return {stringValue:v};
 if (typeof v === 'boolean') return {booleanValue:v};
 if (typeof v === 'number') return Number.isInteger(v)?{integerValue:String(v)}:{doubleValue:v};
 if (Array.isArray(v)) return {arrayValue:v.length?{values:v.map(encode)}:{}};
 return {mapValue:{fields:Object.fromEntries(Object.entries(v).map(([k,v])=>[k,encode(v)]))}};
}
async function main() {
 const cli = process.env.FIREBASE_TOOLS_DIR;
 if (!cli) throw new Error('Set FIREBASE_TOOLS_DIR to the installed Firebase CLI package directory.');
 const auth = require(path.join(cli,'lib/auth.js'));
 const account = auth.getGlobalDefaultAccount();
 if (!account) throw new Error('Sign in with firebase login first.');
 const {access_token} = await auth.getAccessToken(account.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform']);
 async function request(url,body) {
  const r = await fetch(url,{method:body?'POST':'GET',headers:{Authorization:`Bearer ${access_token}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
  if (!r.ok) throw new Error(`Firestore request failed: HTTP ${r.status}`);
  return r.json();
 }
 const database = await request(base);
 assert.equal(database.databaseEdition,'STANDARD'); assert.equal(database.locationId,'us-central1'); assert.equal(database.freeTier,true);
 const manifest = JSON.parse(fs.readFileSync(path.join(root,'content/image-manifest.json')));
 const images = new Map(manifest.images.map(i=>[i.id ?? i.asset, i]));
 const docs = ['knowledge-existing','knowledge-new'].flatMap(name=>{
  const data=JSON.parse(fs.readFileSync(path.join(root,`content/${name}.json`)));
  assert.equal(data.language,'en'); return data.items;
 }).map((item,catalogOrder)=>{
  assert.match(item.id,/^[a-z0-9-]+$/); assert.equal(item.language,'en');
  assert.ok(item.title && item.summary && Array.isArray(item.steps));
  assert.ok(item.imageIds.length > 0, `Article needs a cover: ${item.id}`);
  for (const id of item.imageIds) {
   const image = images.get(id);
   assert.ok(image, `Missing image ${id}`);
   assert.equal(image.uploadStatus, 'verified', `Unverified image ${id}`);
   assert.ok(image.downloadURL?.startsWith(`https://${project}.web.app/editorial/`), `Invalid image URL ${id}`);
   assert.ok(image.knowledgeIds.includes(item.id), `Unmapped image ${id} for ${item.id}`);
  }
  return {name:`projects/${project}/databases/(default)/documents/knowledge/${item.id}`,fields:encode({...item,catalogOrder,schemaVersion:1}).mapValue.fields};
 });
 assert.equal(new Set(docs.map(d=>d.name)).size,docs.length);
 if (!process.argv.includes('--verify-only')) {
  // Updating parent documents preserves all existing comments subcollections.
  await request(`${base}/documents:commit`,{writes:docs.map(update=>({update}))});
 }
 for (const expected of docs) {
  const actual=await request(`https://firestore.googleapis.com/v1/${expected.name}`);
  assert.deepEqual(actual.fields,expected.fields);
 }
 console.log(JSON.stringify({project,database:'(default)',location:database.locationId,verifiedDocuments:docs.length,mode:process.argv.includes('--verify-only')?'verify':'publish-and-verify'},null,2));
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
