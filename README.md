# atf_anyprops-private
📦 ATF AnyProps: Serious RP Placement System

ATF AnyProps คือสคริปต์ที่ถูกออกแบบมาเพื่อเซิร์ฟเวอร์ Serious Roleplay โดยเฉพาะ มุ่งเน้นความสมจริง (Immersion) ประสิทธิภาพสูงสุด (Performance) และความปลอดภัยขั้นสูงสุด (Zero-Trust Architecture) เพื่อให้ผู้เล่นสามารถโต้ตอบกับสภาพแวดล้อมได้โดยไม่ต้องกังวลเรื่องบัคหรือการแสวงหาผลประโยชน์ (Exploit)

🛡️ Core Security Features (Zero-Trust Architecture)

- Server-Side Authoritative: ทุกการกระทำถูกตรวจสอบจากฝั่ง Server 100%
- Anti-NetID Spoofing: ระบบตรวจสอบ Entity Type และ Owner ป้องกันการใช้โปรแกรมโกง
- Decimal & Exploit Buffer: ระบบป้องกันการปั๊มไอเทม
- Ghost Prop Protection: หากการซิงค์ข้อมูลล้มเหลว ระบบจะคืนไอเทมให้ผู้เล่นและทำความสะอาดแมพโดยอัตโนมัติ

🚀 High-Performance & Optimization

- 0.00ms Idle Resmon: ระบบ Dynamic Sleep Thread ทำให้การประมวลผลฝั่ง Client แทบไม่ใช้ทรัพยากรเมื่อไม่ได้ใช้งาน
- OneSync Optimized: โครงสร้างข้อมูลถูกออกแบบมาเพื่อลด Bandwidth ของเซิร์ฟเวอร์ ไม่มีการส่งขยะเข้า StateBag ให้หนักเครื่อง
- Smart Garbage Collection: ระบบเคลียร์ Memory อัตโนมัติ ป้องกันอาการ Memory Leak แม้เซิร์ฟเวอร์จะเปิดต่อเนื่องหลายสัปดาห์

🎭 Roleplay Immersion Features

- Weapons Metadata Support: รองรับการบันทึก Durability, Serial Number, Components, Tint อาวุธที่วางและเก็บขึ้นมาจะเหมือนเดิมเสมอ
- Medical Script Integration: รองรับระบบการสลบ/ตาย (Qbox/QBCore) หากสลบ/ตาย จะไม่สามารถวาง/เก็บของได้
- Real-time Synchronization: ระบบรอ OneSync ป้องกันปัญหา วางปืนแล้วไม่หาย หรือ ของค้างกลางอากาศ

🛠️ Admin & Management Tools

- Mass Operations: คำสั่งกวาดล้าง /prop_mass_pickup และ /prop_mass_delete ที่มีระบบป้องกันเซิร์ฟเวอร์กระตุกระหว่างลบ Prop จำนวนมาก
- Discord Logging: ระบบ Webhook ที่มีคิวหน่วงเวลา ป้องกัน Rate Limit จาก Discord API และบันทึก Log การวางของแบบละเอียด เพื่อการตรวจสอบย้อนหลัง

📋 Technical Specifications

- Framework: Supported QBCore / Qbox
- Inventory: Ox Inventory
- Dependencies: ox_lib, ox_target
- Security: Zero-Trust Architecture
