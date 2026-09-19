/** Hardware adapters emit only normalized UIDs. Never log raw card values. */
export interface CardReader {connect(onCardRead:(uid:string)=>void):Promise<()=>void>}
export class KeyboardWedgeReader implements CardReader {
 async connect(onCardRead:(uid:string)=>void){let buffer='';let last=0;const handler=(e:KeyboardEvent)=>{if((e.target as HTMLElement)?.matches('input,textarea,select'))return;const now=Date.now();if(now-last>80)buffer='';last=now;if(e.key==='Enter'){if(buffer.length>=6){e.preventDefault();onCardRead(buffer)}buffer=''}else if(e.key.length===1){buffer+=e.key}};window.addEventListener('keydown',handler);return()=>window.removeEventListener('keydown',handler)}
}
