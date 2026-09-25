import {type Sale, type Movement} from './model';
import {inRange,schoolDate,type DateRange} from './dates';
export {schoolDate,weekRange,validRange,inRange,type DateRange} from './dates';
export function margin(price:number,cost?:number){return cost===undefined||price===0?null:(price-cost)/price*100}
export type ItemStats={id:string;name:string;units:number;revenue:number;cost:number;missingCost:number};
export function summarize(sales:Sale[],movements:Movement[],range:DateRange){
 const rows=sales.filter(s=>inRange(s.occurred_at,range));const deliveries=movements.filter(m=>m.movement_type==='delivery'&&inRange(m.occurred_at,range));
 const items=new Map<string,ItemStats>(),days=new Map<string,{date:string;revenue:number;sales:number}>();
 let cost=0,missingCost=0,units=0;
 for(const sale of rows){const sign=sale.is_void?-1:1;const date=schoolDate(sale.occurred_at);const day=days.get(date)||{date,revenue:0,sales:0};day.revenue+=sale.total_cents;day.sales+=sale.is_void?0:1;days.set(date,day);
  for(const line of sale.items){const item=items.get(line.product_id)||{id:line.product_id,name:line.product_name,units:0,revenue:0,cost:0,missingCost:0};item.units+=sign*line.quantity;units+=sign*line.quantity;item.revenue+=sign*line.line_total_cents;
   if(line.unit_cost_cents===undefined){missingCost+=line.quantity;item.missingCost+=line.quantity}else{const value=sign*line.quantity*line.unit_cost_cents;cost+=value;item.cost+=value}items.set(item.id,item)}
 }
 const revenue=rows.reduce((n,s)=>n+s.total_cents,0);const saleRows=rows.filter(s=>!s.is_void);const grossSales=saleRows.reduce((n,s)=>n+s.total_cents,0);
 return {revenue,cost,profit:missingCost?null:revenue-cost,missingCost,units,saleCount:saleRows.length,voidCount:rows.length-saleRows.length,average:saleRows.length?Math.round(grossSales/saleRows.length):0,
  deliverySpend:deliveries.reduce((n,m)=>n+m.quantity_delta*(m.unit_cost_cents??0),0),missingDeliveryCost:deliveries.filter(m=>m.unit_cost_cents===undefined).length,
  items:[...items.values()].sort((a,b)=>b.units-a.units||b.revenue-a.revenue||a.name.localeCompare(b.name)),days:[...days.values()].sort((a,b)=>a.date.localeCompare(b.date))};
}
