export type DateRange = {start:string;end:string};
const dateFormatter=new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Zurich',year:'numeric',month:'2-digit',day:'2-digit'});
export function schoolDate(value:string|Date){const parts=dateFormatter.formatToParts(new Date(value));return ['year','month','day'].map(k=>parts.find(p=>p.type===k)!.value).join('-')}
function addDays(date:string,days:number){const d=new Date(`${date}T12:00:00Z`);d.setUTCDate(d.getUTCDate()+days);return d.toISOString().slice(0,10)}
export function weekRange(now=new Date(),previous=false,schoolNights=false):DateRange{const today=schoolDate(now);const weekday=new Date(`${today}T12:00:00Z`).getUTCDay();const start=addDays(today,-weekday-(previous?7:0));return {start,end:addDays(start,schoolNights?4:6)}}
export function validRange(range:DateRange){return /^\d{4}-\d{2}-\d{2}$/.test(range.start)&&/^\d{4}-\d{2}-\d{2}$/.test(range.end)&&range.start<=range.end}
export function inRange(occurred_at:string,range:DateRange){if(!validRange(range))return false;const date=schoolDate(occurred_at);return date>=range.start&&date<=range.end}
