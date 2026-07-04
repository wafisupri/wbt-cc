# Walkabout  
  
**BFI Walkabout: Premium Dark Mode Design Brief**  
**Design Philosophy**  
The goal is to create a professional, industrial-grade experience that feels "premium" rather than just a dark inversion. We focus on **depth, hierarchy, and focused attention**—essential for a safety-critical application.  
The goal is to create a professional, industrial-grade experience that feels "premium" rather than just a dark inversion. We focus on **depth, hierarchy, and focused attention**—essential for a safety-critical application.  
**Core Visual Identity (Based on BFI Guidelines)**  
**Core Visual Identity (Based on BFI Guidelines)**  
* **Background (Surface):** Deep Obsidian (#0F1115) – Allows primary content to pop.  
* **Background (Cards):** Softened Navy-Charcoal (#1A1D24) – Creates subtle depth/layering.  
* **Primary Text:** Off-White (#F8F9FA) – Reduces eye strain compared to pure white.  
* **Secondary Text:** Muted Slate (#94A3B8) – For meta-data and supporting labels.  
* **Brand Accent (BFI Blue):** #005AAB – Reserved for primary buttons and status indicators.  
* **Safety/Alert Accent (Warning):** #FFB800 – Used sparingly to signal mandatory PPE or "Unsafe Condition" flags.  
**Premium Dark Mode Strategies**  
1. **Elevated Elevation:** Use soft, internal box-shadows rather than borders to define cards. box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.3).  
2. **Typography:** Use increased letter spacing for micro-headers and strict weight contrast (Bold for KPIs/Status, Regular for instructions).  
3. **Border Treatments:** Use ultra-thin (0.5px) borders with low opacity (10%) to create separation without visual noise.  
**Functional Requirements & User Experience**  
* **Host Logic:** Dedicated view for the "Safety Representative" to initiate the daily 09:00 walkabout.  
* **Attendance Tracking:** Integration of a "Clock-in" QR scan mechanism at the plant area entry point.  
* **Personalization:** User dashboard pulling data based on ID (BFI, EXP, BRE, INT, IR, C).  
* **Access Control:**  
* **Staff/Partners:** Full history of Walkabout attendance and CARE submissions.  
* **Contractors:** Access to CARE card history only; Walkabout access disabled.  
