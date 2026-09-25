import {test} from 'node:test';
import assert from 'node:assert/strict';
import {weekRange,inRange,schoolDate,validRange,summarize,margin} from '../lib/reports';
import {chargesCsv,makeLines,type Sale,type Product,type Movement} from '../lib/model';
const product:Product={id:'p',name:'Crisps',category:'Snacks',price_cents:250,cost_cents:100,image_url:'',sort_order:0,active:true,low_stock_threshold:5};
function sale(date:string,overrides:Partial<Sale>={}):Sale{return {id:'s',student_id:'student',student_number:'001',student_name:'Test Student',operator_id:'o',operator_name:'Staff',shift_id:'shift',occurred_at:date,total_cents:500,is_void:false,items:makeLines({p:2},[product]),...overrides}}
const range={start:'2026-09-20',end:'2026-09-26'};
test('weekly presets and inclusive school dates include rare Friday/Saturday purchases',()=>{
 assert.deepEqual(weekRange(new Date('2026-09-25T08:00:00Z')),range);
 assert.deepEqual(weekRange(new Date('2026-09-25T08:00:00Z'),true),{start:'2026-09-13',end:'2026-09-19'});
 assert.deepEqual(weekRange(new Date('2026-09-25T08:00:00Z'),false,true),{start:'2026-09-20',end:'2026-09-24'});
 assert.equal(inRange('2026-09-19T22:00:00Z',range),true);
 assert.equal(inRange('2026-09-26T21:59:59Z',range),true);
 assert.equal(inRange('2026-09-26T22:00:00Z',range),false);
 assert.equal(inRange('2026-09-25T19:00:00Z',range),true);
 assert.equal(validRange({start:'2026-09-26',end:'2026-09-20'}),false);
 assert.equal(inRange('2026-09-25T00:00:00Z',{start:'',end:''}),false);
});
test('Zurich day boundaries hold across daylight saving changes',()=>{
 const day={start:'2026-10-25',end:'2026-10-25'};
 assert.equal(inRange('2026-10-24T22:00:00Z',day),true);
 assert.equal(inRange('2026-10-25T22:59:59Z',day),true);
 assert.equal(inRange('2026-10-25T23:00:00Z',day),false);
 assert.equal(schoolDate('2026-03-29T22:00:00Z'),'2026-03-30');
});
test('cost snapshots, refunds, delivery spending and historical product values are independent',()=>{
 const original=sale('2026-09-20T19:00:00Z');
 const later=sale('2026-09-25T19:00:00Z',{id:'later',total_cents:350,items:makeLines({p:1},[{...product,price_cents:350,cost_cents:150}])});
 const reversal={...original,id:'v',occurred_at:'2026-09-26T19:00:00Z',is_void:true,total_cents:-500,original_transaction_id:original.id};
 const delivery:Movement={id:'d',product_id:'p',quantity_delta:10,unit_cost_cents:90,movement_type:'delivery',operator_id:'o',note:'Test',occurred_at:'2026-09-20T10:00:00Z'};
 const stats=summarize([original,later,reversal],[delivery],range);
 assert.equal(stats.revenue,350);assert.equal(stats.cost,150);assert.equal(stats.profit,200);assert.equal(stats.units,1);assert.equal(stats.deliverySpend,900);assert.equal(stats.items[0].units,1);assert.equal(stats.saleCount,2);assert.equal(stats.voidCount,1);
 assert.equal(original.items[0].unit_cost_cents,100);assert.equal(original.items[0].unit_price_cents,250);
 const refundOnly=summarize([original,reversal],[],{start:'2026-09-26',end:'2026-09-26'});assert.equal(refundOnly.revenue,-500);assert.equal(refundOnly.cost,-200);assert.equal(refundOnly.profit,-300);
});
test('missing costs are not silently treated as free stock and zero cost is valid',()=>{
 const old=sale('2026-09-20T19:00:00Z',{items:makeLines({p:2},[{...product,cost_cents:undefined}])});
 assert.equal(summarize([old],[],range).profit,null);assert.equal(summarize([old],[],range).missingCost,2);
 const free=sale('2026-09-20T19:00:00Z',{items:makeLines({p:2},[{...product,cost_cents:0}])});assert.equal(summarize([free],[],range).profit,500);assert.equal(margin(250,0),100);assert.equal(margin(0,100),null);assert.equal(margin(250,undefined),null);
 assert.equal(margin(250,300),-20);
});
test('date-filtered export includes local dates, stable identifiers and reversals',()=>{
 const rows=[sale('2026-09-19T21:59:59Z',{id:'outside'}),sale('2026-09-19T22:00:00Z',{id:'inside'}),sale('2026-09-26T21:59:59Z',{id:'reverse',is_void:true,total_cents:-500,original_transaction_id:'inside',note:'Wrong student'})];
 const csv=chargesCsv(rows.filter(s=>inRange(s.occurred_at,range)));
 assert.ok(!csv.includes('outside'));assert.ok(csv.includes('2026-09-20'));assert.ok(csv.includes('reverse'));assert.ok(csv.includes('Wrong student'));assert.ok(csv.includes('Europe/Zurich'));assert.ok(csv.includes('\"-5.00\"'));assert.ok(!csv.includes("'-5.00"));
});
