/** Production outbox runner. Do not attach the practice database to this worker. */
export type PendingEvent={id:string;kind:string;payload:unknown;occurred_at:string};
export interface SyncStore {pending():Promise<PendingEvent[]>;markSynced(id:string):Promise<void>;markError(id:string,error:string):Promise<void>}
export interface SyncTransport {push(event:PendingEvent):Promise<{accepted_id:string}>}
export function createSyncWorker(store:SyncStore,transport:SyncTransport){
 let running=false,stopped=false,timer:ReturnType<typeof setTimeout>|undefined,delay=2000;
 async function flush(){if(running||stopped)return;running=true;
 try{const rows=await store.pending();rows.sort((a,b)=>a.occurred_at.localeCompare(b.occurred_at));for(const row of rows){try{const receipt=await transport.push(row);if(receipt.accepted_id!==row.id)throw Error('Server did not acknowledge this event');await store.markSynced(row.id)}catch(error){await store.markError(row.id,error instanceof Error?error.message:'Sync failed');throw error}}delay=2000}
 catch{delay=Math.min(delay*2,60000)}finally{running=false;if(!stopped)timer=setTimeout(flush,delay)}}
 return{start(){stopped=false;void flush()},flush,stop(){stopped=true;if(timer)clearTimeout(timer)}}
}
export function syncHealth(events:PendingEvent[],now=Date.now()) {return{pending:events.length,needsAttention:events.length>50||events.some(e=>now-Date.parse(e.occurred_at)>86400000)}}
