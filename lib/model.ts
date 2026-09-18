export type Role = 'staff' | 'prefect';
export type Product = {id:string;name:string;category:string;price_cents:number;image_url:string;sort_order:number;active:boolean;low_stock_threshold:number};
export type Student = {id:string;student_number:string;first_name:string;last_name:string;dorm:string;active:boolean;card_uid_hash?:string;spending_limit_cents?:number};
export type Operator = {id:string;name:string;role:Role;pin_salt:string;pin_hash:string};
export type Shift = {id:string;operator_id:string;operator_name:string;role:Role;opened_at:string;closed_at?:string};
export type Line = {product_id:string;product_name:string;quantity:number;unit_price_cents:number;line_total_cents:number};
export type Sale = {id:string;student_id:string;student_number:string;student_name:string;shift_id:string;operator_id:string;operator_name:string;total_cents:number;occurred_at:string;is_void:boolean;original_transaction_id?:string;note?:string;items:Line[]};
export type Movement = {id:string;product_id:string;quantity_delta:number;movement_type:'delivery'|'sale'|'void'|'count_correction';transaction_id?:string;operator_id:string;note:string;occurred_at:string};
export type Event = {id:string;kind:'sale'|'void'|'delivery'|'product'|'student'|'shift'|'operator'|'count';payload:unknown;occurred_at:string;actor_id:string;status:'pending'|'synced';error?:string};
export type Count = {id:string;operator_id:string;occurred_at:string;lines:{product_id:string;expected_qty:number;counted_qty:number}[]};
export const money=(cents:number)=>`CHF ${(cents/100).toFixed(2)}`;
export const uuid=()=>crypto.randomUUID();
export function makeLines(cart:Record<string,number>,products:Product[]):Line[]{return Object.entries(cart).filter(([,q])=>q>0).map(([id,quantity])=>{const p=products.find(p=>p.id===id);if(!p||!Number.isSafeInteger(quantity)||quantity>1000)throw Error('Invalid cart');return{product_id:id,product_name:p.name,quantity,unit_price_cents:p.price_cents,line_total_cents:quantity*p.price_cents}})}
export function stockFor(id:string,movements:Movement[]){return movements.filter(m=>m.product_id===id).reduce((a,m)=>a+m.quantity_delta,0)}
export function csvCell(value:unknown){let s=String(value??'');if(/^[=+\-@\t\r]/.test(s))s="'"+s;return '"'+s.replaceAll('"','""')+'"'}
export function chargesCsv(sales:Sale[]){return [['Date','Student number','Student','Items','Total CHF','Operator','Transaction ID','Reverses','Note'],...sales.map(s=>[s.occurred_at,s.student_number,s.student_name,s.items.map(i=>`${i.quantity} × ${i.product_name}`).join('; '),(s.total_cents/100).toFixed(2),s.operator_name,s.id,s.original_transaction_id||'',s.note||''])].map(row=>row.map(csvCell).join(',')).join('\r\n')}
