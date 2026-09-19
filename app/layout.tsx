import type {Metadata,Viewport} from 'next';
import './globals.css';
export const metadata:Metadata={title:'Savoy Store · LAS',description:'Staff register and inventory for the LAS Savoy dorm store.',manifest:'/manifest.webmanifest',icons:{icon:'/favicon.svg',apple:'/icon.svg'}};
export const viewport:Viewport={themeColor:'#101917',width:'device-width',initialScale:1};
export default function Layout({children}:{children:React.ReactNode}){return <html lang="en"><body>{children}</body></html>}
