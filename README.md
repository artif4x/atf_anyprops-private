# atf_anyprops-private
📦 ATF AnyProps: Hold Props & Placement System

📋 Technical Specifications

- Framework: QBCore / Qbox
- Inventory: ox_inventory
- Dependencies: ox_lib, ox_target

🎭 Core Features
- Hold & Place Any Assign Props: ถือและวาง Item Prop ได้ทุกชิ้นที่ตั้งค่าใน Config
- Place Any Weapon: วางอาวุธได้ทุกชนิดโดยไม่จำเป็นต้อง Config ใดๆ
- Weapons Metadata Support: รองรับการบันทึก Durability, Serial Number, Components, Tint อาวุธที่วางและเก็บขึ้นมาจะเหมือนเดิมเสมอ
- Real-time Synchronization: ระบบรอ OneSync ป้องกันปัญหา วางปืนแล้วไม่หาย หรือ ของค้างกลางอากาศ และทุกคนจะเห็นของตรงกัน

🚀 High-Performance & Optimization

- 0.00ms Idle Resmon: ระบบ Dynamic Sleep Thread การประมวลผลฝั่ง Client แทบไม่ใช้ทรัพยากรเมื่อไม่ได้ใช้งาน
- OneSync Optimized: ลด Bandwidth ของ Server ไม่มีการส่งขยะเข้า StateBag ให้หนักเครื่อง
- Garbage Collection: ระบบเคลียร์ Memory อัตโนมัติ ป้องกัน Memory Leak

🛡️ Security Features (Zero-Trust Architecture)

- Server-Side Authoritative: ทุกการกระทำถูกตรวจสอบจากฝั่ง Server 100%
- Anti-NetID Spoofing: ระบบตรวจสอบ Entity Type และ Owner ป้องกันการใช้โปรแกรมโกง
- Decimal & Exploit Buffer: ระบบป้องกันการปั๊มไอเทม
- Ghost Prop Protection: หากการซิงค์ข้อมูลล้มเหลว ระบบจะคืนไอเทมให้ผู้เล่นและทำความสะอาดแมพโดยอัตโนมัติ

🛠️ Admin & Management Tools

- Mass Operations: คำสั่งกวาดล้าง /prop_mass_pickup และ /prop_mass_delete ที่มีระบบป้องกันเซิร์ฟเวอร์กระตุกระหว่างลบ Prop จำนวนมาก
- Discord Logging: ระบบ Webhook ที่มีคิวหน่วงเวลา ป้องกัน Rate Limit จาก Discord API และบันทึก Log การวางของแบบละเอียด เพื่อการตรวจสอบย้อนหลัง
