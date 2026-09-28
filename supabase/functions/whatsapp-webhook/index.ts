import {createClient} from "https://esm.sh/@supabase/supabase-js@2";
const URL=Deno.env.get("SUPABASE_URL")!,KEY=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,VERIFY=Deno.env.get("WHATSAPP_VERIFY_TOKEN")!,APP_SECRET=Deno.env.get("META_APP_SECRET")!;
const db=createClient(URL,KEY);
const enc=new TextEncoder();
function hex(b:ArrayBuffer){return [...new Uint8Array(b)].map(x=>x.toString(16).padStart(2,"0")).join("")}
function equal(a:string,b:string){if(a.length!==b.length)return false;let r=0;for(let i=0;i<a.length;i++)r|=a.charCodeAt(i)^b.charCodeAt(i);return r===0}
async function valid(raw:string,sig:string|null){if(!sig||!APP_SECRET)return false;const key=await crypto.subtle.importKey("raw",enc.encode(APP_SECRET),{name:"HMAC",hash:"SHA-256"},false,["sign"]);const out=await crypto.subtle.sign("HMAC",key,enc.encode(raw));return equal("sha256="+hex(out),sig)}
function textOf(m:any){if(m?.type==="text")return m.text?.body?.trim()||"";return ""}
Deno.serve(async req=>{try{
 if(req.method==="GET"){const u=new URL(req.url);if(u.searchParams.get("hub.mode")==="subscribe"&&u.searchParams.get("hub.verify_token")===VERIFY)return new Response(u.searchParams.get("hub.challenge")||"",{status:200});return new Response("Forbidden",{status:403})}
 if(req.method!=="POST")return new Response("Method not allowed",{status:405});
 const raw=await req.text();if(!await valid(raw,req.headers.get("x-hub-signature-256")))return new Response("Unauthorized",{status:401});
 const body=JSON.parse(raw);
 for(const entry of body.entry??[])for(const change of entry.changes??[]){if(change.field!=="messages")continue;const value=change.value??{};const phoneId=value.metadata?.phone_number_id;if(!phoneId)continue;
  const{data:wa}=await db.from("whatsapp_settings").select("barbershop_id").eq("phone_number_id",phoneId).maybeSingle();if(!wa)continue;
  for(const st of value.statuses??[]){if(st.id&&st.status)await db.from("messages").update({status:st.status}).eq("external_message_id",st.id).eq("barbershop_id",wa.barbershop_id)}
  for(const m of value.messages??[]){if(!m.id||!m.from)continue;const bodyText=textOf(m);if(!bodyText)continue;
   const{data:existing}=await db.from("messages").select("id").eq("external_message_id",m.id).maybeSingle();if(existing)continue;
   const contact=value.contacts?.find((c:any)=>c.wa_id===m.from);const customerName=contact?.profile?.name||null;
   let{data:customer}=await db.from("customers").select("id,name").eq("barbershop_id",wa.barbershop_id).eq("whatsapp_phone",m.from).maybeSingle();
   if(!customer){const created=await db.from("customers").insert({barbershop_id:wa.barbershop_id,whatsapp_phone:m.from,name:customerName}).select("id,name").single();if(created.error)throw created.error;customer=created.data}else if(!customer.name&&customerName)await db.from("customers").update({name:customerName,updated_at:new Date().toISOString()}).eq("id",customer.id);
   let{data:conv}=await db.from("conversations").select("id,mode,unread_count").eq("barbershop_id",wa.barbershop_id).eq("customer_id",customer.id).maybeSingle();
   if(!conv){const created=await db.from("conversations").insert({barbershop_id:wa.barbershop_id,customer_id:customer.id,mode:"ai",unread_count:1,last_message_at:new Date().toISOString()}).select("id,mode,unread_count").single();if(created.error)throw created.error;conv=created.data}else await db.from("conversations").update({last_message_at:new Date().toISOString(),unread_count:(conv.unread_count??0)+1,updated_at:new Date().toISOString()}).eq("id",conv.id);
   const ins=await db.from("messages").insert({barbershop_id:wa.barbershop_id,conversation_id:conv.id,direction:"inbound",source:"customer",body:bodyText,external_message_id:m.id,status:"received"});if(ins.error&&ins.error.code!=="23505")throw ins.error;
  }
 }
 return new Response("EVENT_RECEIVED",{status:200});
}catch(e){console.error(e);return new Response("Internal error",{status:500})}});