# atf_anyprops-private
📦 ATF AnyProps: Serious RP Placement System
"ยกระดับการ Roleplay ด้วยระบบการวางไอเทมและอาวุธระดับ Production Grade ที่ปลอดภัยที่สุด"

ATF AnyProps คือสคริปต์ที่ถูกออกแบบมาเพื่อเซิร์ฟเวอร์ Serious Roleplay โดยเฉพาะ มุ่งเน้นความสมจริง (Immersion) ประสิทธิภาพสูงสุด (Performance) และความปลอดภัยขั้นสูงสุด (Zero-Trust Architecture) เพื่อให้ผู้เล่นสามารถโต้ตอบกับสภาพแวดล้อมได้โดยไม่ต้องกังวลเรื่องบัคหรือการแสวงหาผลประโยชน์ (Exploit)

🛡️ Core Security Features (Zero-Trust Architecture)
เราไม่ได้แค่สร้างระบบให้วางของได้ แต่เราสร้าง "ป้อมปราการ" ให้กับเซิร์ฟเวอร์ของคุณ

Server-Side Authoritative: ทุกการกระทำถูกตรวจสอบจากฝั่ง Server 100% ไม่เชื่อใจ Client

Anti-NetID Spoofing: ระบบตรวจสอบ Entity Type และ Owner ของโมเดลอย่างแม่นยำ ป้องกันการใช้โปรแกรมโกง (Mod Menu) ในการสวมรอยหรือลบ Prop ของผู้อื่น

Decimal & Exploit Buffer: ระบบป้องกันการปั๊มไอเทมผ่านตัวเลขทศนิยมและการลักไก่วางของนอกระยะด้วย Exploit Buffer ที่แม่นยำ

Ghost Prop Protection: ระบบจัดการโมเดลผีอัจฉริยะ หากการซิงค์ข้อมูลล้มเหลว ระบบจะคืนไอเทมให้ผู้เล่นและทำความสะอาดแมพโดยอัตโนมัติ

🚀 High-Performance & Optimization
0.00ms Idle Resmon: ระบบ Dynamic Sleep Thread ที่ปรับแต่งอย่างละเอียด ทำให้การประมวลผลฝั่ง Client แทบไม่ใช้ทรัพยากรเมื่อไม่ได้ใช้งาน

OneSync Optimized: โครงสร้างข้อมูลถูกออกแบบมาเพื่อลด Bandwidth ของเซิร์ฟเวอร์ ไม่มีการส่งขยะเข้า StateBag ให้หนักเครื่อง

Smart Garbage Collection: ระบบเคลียร์ Memory อัตโนมัติ ป้องกันอาการ Memory Leak แม้เซิร์ฟเวอร์จะเปิดต่อเนื่องหลายสัปดาห์

🎭 Roleplay Immersion Features
Weapons Metadata Support: รองรับการวางอาวุธแบบคงสภาพ (Serial Number, Components, Tint) ปืนที่วางจะเหมือนกับปืนในกระเป๋าทุกประการ

Medical Script Integration: รองรับระบบการสลบ/ตายของทุกค่าย (Qbox/QBCore) ระบบจะตัดการโต้ตอบ (ox_target) และซ่อน UI ทันทีเมื่อตัวละครหมดสภาพ เพิ่มความสมจริงในการปล้นหรือทำกิจกรรม

Real-time Synchronization: ระบบรอการซิงค์ OneSync ที่อัจฉริยะ ป้องกันปัญหา "วางปืนแล้วไม่หาย" หรือ "ของค้างกลางอากาศ"

🛠️ Admin & Management Tools
Mass Operations: คำสั่งกวาดล้าง /prop_mass_pickup และ /prop_mass_delete ที่มีระบบ Yield Thread ป้องกันเซิร์ฟเวอร์กระตุกระหว่างลบ Prop จำนวนมาก

Discord Logging: ระบบ Webhook ที่มีคิวหน่วงเวลา ป้องกัน Rate Limit จาก Discord API และบันทึก Log การวางของแบบละเอียด เพื่อการตรวจสอบย้อนหลังที่ง่ายดาย

📋 Technical Specifications
Framework: Supported QBCore / Qbox

Inventory: Ox Inventory

Dependencies: ox_lib, ox_target

Security Rating: Masterpiece / Zero-Trust

"ATF AnyProps ไม่ใช่แค่สคริปต์วางของ แต่คือระบบที่ทำให้คุณหลับสบายในฐานะเจ้าของเซิร์ฟเวอร์ เพราะคุณจะไม่ต้องแก้บัคจุกจิก หรือปวดหัวกับแฮกเกอร์อีกต่อไป"
