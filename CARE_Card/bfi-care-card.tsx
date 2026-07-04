import React, { useState, useEffect, useRef } from "react";

const CARD_TYPES = [
  {
    id: "intervene",
    label: "Intervene",
    color: "#E4572E",
    tag: "Stop-the-job",
    desc: "You saw something and acted immediately, before it became an incident.",
  },
  {
    id: "unsafe-act",
    label: "Prevent Unsafe Act",
    color: "#F0A83A",
    tag: "Behaviour",
    desc: "A behaviour that could have caused harm — caught before it did.",
  },
  {
    id: "unsafe-condition",
    label: "Prevent Unsafe Condition",
    color: "#3E7CB1",
    tag: "Environment",
    desc: "Equipment, layout, or process risk you flagged on the ground.",
  },
  {
    id: "suggestion",
    label: "Suggestion",
    color: "#4C9A6A",
    tag: "Improvement",
    desc: "An idea that makes the job safer, not just compliant.",
  },
];

const ROLES = [
  "BFI Staff",
  "I-Ready Apprentice",
  "Internship Student",
  "BRE Business Partner",
  "Contractor",
];

const HSSE_EMAIL = "hsse.oss@bfi.com.bn"; // placeholder — replace with real HSSE OSS inbox

function monthKey(d = new Date()) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}
function monthLabel(d = new Date()) {
  return d.toLocaleDateString("en-GB", { month: "long", year: "numeric" });
}

export default function App() {
  const [reducedMotion, setReducedMotion] = useState(false);
  const [dealt, setDealt] = useState(false);
  const [monthCount, setMonthCount] = useState(null);
  const [countError, setCountError] = useState(false);
  const [step, setStep] = useState(0); // 0 role, 1 type, 2 details, 3 review, 4 done
  const [form, setForm] = useState({
    name: "",
    role: "",
    cardType: "",
    location: "",
    description: "",
  });
  const [refNumber, setRefNumber] = useState("");
  const formRef = useRef(null);

  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    setReducedMotion(mq.matches);
    const t = setTimeout(() => setDealt(true), reducedMotion ? 0 : 120);
    loadCount();
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function loadCount() {
    try {
      const res = await window.storage.list(`care-submissions:${monthKey()}:`, true);
      setMonthCount(res ? res.keys.length : 0);
    } catch (e) {
      setCountError(true);
      setMonthCount(0);
    }
  }

  const selectedType = CARD_TYPES.find((c) => c.id === form.cardType);
  const accent = selectedType ? selectedType.color : "#8A97A0";

  function update(field, value) {
    setForm((f) => ({ ...f, [field]: value }));
  }

  function scrollToForm() {
    formRef.current?.scrollIntoView({ behavior: reducedMotion ? "auto" : "smooth", block: "start" });
  }

  function pickTypeAndGo(id) {
    update("cardType", id);
    setStep((s) => Math.max(s, 1));
    scrollToForm();
  }

  const canNext = [
    !!form.role,
    !!form.cardType,
    form.location.trim() && form.description.trim().length >= 10,
  ];

  async function handleSubmit() {
    const now = new Date();
    const mk = monthKey(now);
    const ref = `CARE-${mk.replace("-", "")}-${Math.floor(1000 + Math.random() * 9000)}`;
    setRefNumber(ref);
    try {
      await window.storage.set(
        `care-submissions:${mk}:${ref}`,
        JSON.stringify({ ...form, ref, submittedAt: now.toISOString() }),
        true
      );
      const res = await window.storage.list(`care-submissions:${mk}:`, true);
      setMonthCount(res ? res.keys.length : (monthCount || 0) + 1);
    } catch (e) {
      console.error("Storage error:", e);
    }
    const subject = encodeURIComponent(
      `BFI CARE Card — ${selectedType?.label || ""} — ${form.name || form.role}`
    );
    const body = encodeURIComponent(
      `CARE Card Reference: ${ref}\nSubmitted by: ${form.name || "(not provided)"} (${form.role})\nCard type: ${selectedType?.label}\nLocation: ${form.location}\nDate: ${now.toLocaleDateString("en-GB")}\n\nDescription:\n${form.description}\n`
    );
    window.open(`mailto:${HSSE_EMAIL}?subject=${subject}&body=${body}`, "_blank");
    setStep(4);
  }

  function resetForm() {
    setForm({ name: "", role: "", cardType: "", location: "", description: "" });
    setStep(0);
    setRefNumber("");
  }

  return (
    <div style={{ background: "#1B2024", color: "#EDEBE6", minHeight: "100vh" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Oswald:wght@400;500;600;700&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap');
        * { box-sizing: border-box; }
        .disp { font-family: 'Oswald', sans-serif; letter-spacing: 0.01em; text-transform: uppercase; }
        .body-f { font-family: 'IBM Plex Sans', sans-serif; }
        .mono { font-family: 'IBM Plex Mono', monospace; }
        .focus-ring:focus-visible { outline: 2px solid #F0A83A; outline-offset: 3px; }
        @keyframes deal {
          from { opacity: 0; transform: translateY(24px) rotate(var(--r0)); }
          to { opacity: 1; transform: translateY(0) rotate(var(--r1)); }
        }
        @keyframes riseIn {
          from { opacity: 0; transform: translateY(14px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .deal-card { animation: deal 0.7s cubic-bezier(.2,.8,.2,1) both; }
        .rise { animation: riseIn 0.6s ease both; }
        @media (prefers-reduced-motion: reduce) {
          .deal-card, .rise { animation: none !important; }
        }
      `}</style>

      {/* NAV */}
      <nav
        className="body-f"
        style={{
          position: "sticky",
          top: 0,
          zIndex: 40,
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: "14px 20px",
          background: "rgba(27,32,36,0.9)",
          backdropFilter: "blur(6px)",
          borderBottom: "1px solid #2C3339",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <div
            style={{
              width: 10,
              height: 10,
              background: "#F0A83A",
              transform: "rotate(45deg)",
            }}
          />
          <span className="disp" style={{ fontSize: 15, fontWeight: 600 }}>
            BFI CARE Card
          </span>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
          <span
            className="mono"
            style={{ fontSize: 12, color: "#9AA5AC", display: "none" }}
            id="nav-count-spacer"
          />
          <span className="mono" style={{ fontSize: 12, color: "#B7C0C6" }}>
            {monthCount === null ? "—" : `${monthCount} submitted · ${monthLabel()}`}
          </span>
          <button
            onClick={scrollToForm}
            className="focus-ring"
            style={{
              background: "#F0A83A",
              color: "#1B2024",
              border: "none",
              padding: "8px 14px",
              fontFamily: "'IBM Plex Sans', sans-serif",
              fontWeight: 600,
              fontSize: 13,
              cursor: "pointer",
            }}
          >
            Submit this month's card
          </button>
        </div>
      </nav>

      {/* HERO */}
      <section style={{ padding: "64px 20px 40px", maxWidth: 1100, margin: "0 auto" }}>
        <div
          className="mono"
          style={{ fontSize: 12, color: "#F0A83A", marginBottom: 14, letterSpacing: "0.08em" }}
        >
          BFI HSSE · OSS SECTION — MONTHLY INTERVENTION PROGRAMME
        </div>
        <div style={{ display: "grid", gridTemplateColumns: "1.1fr 0.9fr", gap: 36, alignItems: "center" }}>
          <div>
            <h1
              className="disp"
              style={{ fontSize: "clamp(32px, 5vw, 56px)", lineHeight: 1.05, fontWeight: 700, margin: 0 }}
            >
              Every observation
              <br />
              counts. Every month,
              <br />
              <span style={{ color: "#F0A83A" }}>everyone.</span>
            </h1>
            <p className="body-f" style={{ fontSize: 16, color: "#B7C0C6", marginTop: 18, maxWidth: 460 }}>
              Control And Remedial Effect. One card, one month — from every person on
              site, no exceptions. Four ways to act on what you see.
            </p>
            <div style={{ display: "flex", gap: 12, marginTop: 26, flexWrap: "wrap" }}>
              <button
                onClick={scrollToForm}
                className="focus-ring"
                style={{
                  background: "#E4572E",
                  color: "#fff",
                  border: "none",
                  padding: "13px 22px",
                  fontFamily: "'IBM Plex Sans', sans-serif",
                  fontWeight: 600,
                  fontSize: 14,
                  cursor: "pointer",
                }}
              >
                Submit this month's card →
              </button>
              <a
                href="#types"
                className="focus-ring body-f"
                style={{
                  color: "#EDEBE6",
                  border: "1px solid #3A4148",
                  padding: "13px 22px",
                  fontSize: 14,
                  textDecoration: "none",
                  fontWeight: 500,
                }}
              >
                See the four card types
              </a>
            </div>
          </div>

          {/* Card fan */}
          <div style={{ position: "relative", height: 260 }}>
            {CARD_TYPES.map((c, i) => {
              const rot = (i - 1.5) * 7;
              return (
                <div
                  key={c.id}
                  className={dealt ? "deal-card" : ""}
                  style={{
                    "--r0": `${rot - 4}deg`,
                    "--r1": `${rot}deg`,
                    animationDelay: `${i * 90}ms`,
                    position: "absolute",
                    left: "50%",
                    top: 20,
                    width: 168,
                    height: 210,
                    background: "#EFEAE1",
                    color: "#1B2024",
                    borderRadius: 6,
                    boxShadow: "0 12px 24px rgba(0,0,0,0.35)",
                    transform: `translateX(-50%) rotate(${dealt ? rot : rot - 4}deg)`,
                    transformOrigin: "bottom center",
                    padding: 14,
                    display: "flex",
                    flexDirection: "column",
                    justifyContent: "space-between",
                  }}
                >
                  <div style={{ width: 30, height: 6, background: c.color, borderRadius: 3 }} />
                  <div>
                    <div className="disp" style={{ fontSize: 13, fontWeight: 600, lineHeight: 1.15 }}>
                      {c.label}
                    </div>
                    <div className="mono" style={{ fontSize: 9, color: "#6B7580", marginTop: 6 }}>
                      {c.tag.toUpperCase()}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </section>

      {/* WHO */}
      <section className="rise" style={{ padding: "20px 20px 50px", maxWidth: 1100, margin: "0 auto" }}>
        <div className="body-f" style={{ fontSize: 13, color: "#8A97A0", marginBottom: 12 }}>
          Mandatory for everyone on site
        </div>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 10 }}>
          {ROLES.map((r) => (
            <span
              key={r}
              className="body-f"
              style={{
                border: "1px solid #3A4148",
                padding: "8px 14px",
                borderRadius: 999,
                fontSize: 13,
                color: "#DCE1E4",
              }}
            >
              {r}
            </span>
          ))}
        </div>
      </section>

      {/* FOUR TYPES */}
      <section id="types" style={{ padding: "10px 20px 60px", maxWidth: 1100, margin: "0 auto" }}>
        <h2 className="disp" style={{ fontSize: 26, fontWeight: 600, marginBottom: 4 }}>
          Pick what you saw
        </h2>
        <p className="body-f" style={{ color: "#8A97A0", marginBottom: 24, fontSize: 14 }}>
          Every card falls into one of four types. Tap one to start your submission.
        </p>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(230px, 1fr))", gap: 16 }}>
          {CARD_TYPES.map((c) => (
            <button
              key={c.id}
              onClick={() => pickTypeAndGo(c.id)}
              className="focus-ring"
              style={{
                textAlign: "left",
                background: "#22282D",
                border: "1px solid #2C3339",
                borderTop: `4px solid ${c.color}`,
                borderRadius: 4,
                padding: 18,
                cursor: "pointer",
                transition: "transform 0.15s ease, box-shadow 0.15s ease",
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = "translateY(-4px)";
                e.currentTarget.style.boxShadow = "0 10px 20px rgba(0,0,0,0.3)";
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = "translateY(0)";
                e.currentTarget.style.boxShadow = "none";
              }}
            >
              <div className="mono" style={{ fontSize: 11, color: c.color, marginBottom: 6 }}>
                {c.tag.toUpperCase()}
              </div>
              <div className="disp" style={{ fontSize: 17, fontWeight: 600, marginBottom: 8 }}>
                {c.label}
              </div>
              <div className="body-f" style={{ fontSize: 13, color: "#AEB7BD", lineHeight: 1.4 }}>
                {c.desc}
              </div>
            </button>
          ))}
        </div>
      </section>

      {/* FORM — the card stub */}
      <section ref={formRef} style={{ padding: "20px 20px 80px", maxWidth: 720, margin: "0 auto" }}>
        <h2 className="disp" style={{ fontSize: 26, fontWeight: 600, marginBottom: 4 }}>
          This month's card
        </h2>
        <p className="body-f" style={{ color: "#8A97A0", marginBottom: 24, fontSize: 14 }}>
          Takes under a minute. Sent straight to HSSE OSS.
        </p>

        <div
          style={{
            background: "#EFEAE1",
            color: "#1B2024",
            borderRadius: 8,
            overflow: "hidden",
            boxShadow: "0 20px 40px rgba(0,0,0,0.35)",
          }}
        >
          <div style={{ height: 6, background: accent, transition: "background 0.3s ease" }} />
          <div style={{ padding: "24px 26px" }}>
            {/* stub header */}
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "baseline",
                borderBottom: "1px dashed #C9C2B4",
                paddingBottom: 12,
                marginBottom: 20,
              }}
            >
              <span className="disp" style={{ fontSize: 14, fontWeight: 600 }}>
                CARE CARD STUB
              </span>
              <span className="mono" style={{ fontSize: 11, color: "#6B7580" }}>
                {monthLabel()}
              </span>
            </div>

            {step === 0 && (
              <div className="rise">
                <label className="body-f" style={{ fontSize: 13, fontWeight: 600, display: "block", marginBottom: 8 }}>
                  Your name (optional)
                </label>
                <input
                  value={form.name}
                  onChange={(e) => update("name", e.target.value)}
                  placeholder="e.g. Wafi Supri"
                  className="body-f focus-ring"
                  style={inputStyle}
                />
                <label className="body-f" style={{ fontSize: 13, fontWeight: 600, display: "block", margin: "16px 0 8px" }}>
                  Your role
                </label>
                <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
                  {ROLES.map((r) => (
                    <button
                      key={r}
                      onClick={() => update("role", r)}
                      className="body-f focus-ring"
                      style={{
                        padding: "8px 12px",
                        borderRadius: 999,
                        fontSize: 13,
                        cursor: "pointer",
                        border: form.role === r ? `1.5px solid ${accent}` : "1px solid #C9C2B4",
                        background: form.role === r ? "#fff" : "transparent",
                        fontWeight: form.role === r ? 600 : 400,
                      }}
                    >
                      {r}
                    </button>
                  ))}
                </div>
                <StepNav onNext={() => setStep(1)} nextDisabled={!canNext[0]} first />
              </div>
            )}

            {step === 1 && (
              <div className="rise">
                <label className="body-f" style={{ fontSize: 13, fontWeight: 600, display: "block", marginBottom: 10 }}>
                  Card type
                </label>
                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
                  {CARD_TYPES.map((c) => (
                    <button
                      key={c.id}
                      onClick={() => update("cardType", c.id)}
                      className="body-f focus-ring"
                      style={{
                        textAlign: "left",
                        padding: 12,
                        borderRadius: 6,
                        cursor: "pointer",
                        border: form.cardType === c.id ? `1.5px solid ${c.color}` : "1px solid #C9C2B4",
                        background: form.cardType === c.id ? "#fff" : "transparent",
                      }}
                    >
                      <div style={{ width: 20, height: 4, background: c.color, borderRadius: 2, marginBottom: 6 }} />
                      <div style={{ fontSize: 13, fontWeight: 600 }}>{c.label}</div>
                    </button>
                  ))}
                </div>
                <StepNav onBack={() => setStep(0)} onNext={() => setStep(2)} nextDisabled={!canNext[1]} />
              </div>
            )}

            {step === 2 && (
              <div className="rise">
                <label className="body-f" style={{ fontSize: 13, fontWeight: 600, display: "block", marginBottom: 8 }}>
                  Location
                </label>
                <input
                  value={form.location}
                  onChange={(e) => update("location", e.target.value)}
                  placeholder="e.g. Ammonia Plant, Loading Bay 2"
                  className="body-f focus-ring"
                  style={inputStyle}
                />
                <label className="body-f" style={{ fontSize: 13, fontWeight: 600, display: "block", margin: "16px 0 8px" }}>
                  What did you observe?
                </label>
                <textarea
                  value={form.description}
                  onChange={(e) => update("description", e.target.value)}
                  placeholder="Describe what happened and what you did or suggest."
                  rows={4}
                  className="body-f focus-ring"
                  style={{ ...inputStyle, resize: "vertical" }}
                />
                <div className="mono" style={{ fontSize: 11, color: "#8A8375", marginTop: 6 }}>
                  {form.description.trim().length}/10 characters minimum
                </div>
                <StepNav onBack={() => setStep(1)} onNext={() => setStep(3)} nextDisabled={!canNext[2]} />
              </div>
            )}

            {step === 3 && (
              <div className="rise">
                <div className="mono" style={{ fontSize: 11, color: "#6B7580", marginBottom: 10 }}>
                  REVIEW BEFORE SENDING
                </div>
                <ReviewRow label="Name" value={form.name || "—"} />
                <ReviewRow label="Role" value={form.role} />
                <ReviewRow label="Card type" value={selectedType?.label} accent={accent} />
                <ReviewRow label="Location" value={form.location} />
                <ReviewRow label="Description" value={form.description} block />
                <StepNav onBack={() => setStep(2)} onNext={handleSubmit} nextLabel="Send card →" />
              </div>
            )}

            {step === 4 && (
              <div className="rise" style={{ textAlign: "center", padding: "20px 0" }}>
                <div
                  style={{
                    width: 48,
                    height: 48,
                    borderRadius: "50%",
                    background: accent,
                    color: "#fff",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    margin: "0 auto 14px",
                    fontSize: 22,
                  }}
                >
                  ✓
                </div>
                <div className="disp" style={{ fontSize: 18, fontWeight: 600 }}>
                  Card ready to send
                </div>
                <div className="mono" style={{ fontSize: 12, color: "#6B7580", marginTop: 6 }}>
                  Reference {refNumber}
                </div>
                <p className="body-f" style={{ fontSize: 13, color: "#5A6067", marginTop: 12, maxWidth: 380, marginLeft: "auto", marginRight: "auto" }}>
                  Your email client should have opened with the card pre-filled to HSSE
                  OSS. If it didn't,{" "}
                  <a
                    href={`mailto:${HSSE_EMAIL}?subject=${encodeURIComponent(
                      `BFI CARE Card — ${selectedType?.label || ""} — ${form.name || form.role}`
                    )}&body=${encodeURIComponent(
                      `CARE Card Reference: ${refNumber}\nSubmitted by: ${form.name || "(not provided)"} (${form.role})\nCard type: ${selectedType?.label}\nLocation: ${form.location}\n\nDescription:\n${form.description}`
                    )}`}
                    style={{ color: accent, fontWeight: 600 }}
                  >
                    click here to send it
                  </a>
                  .
                </p>
                <button
                  onClick={resetForm}
                  className="body-f focus-ring"
                  style={{
                    marginTop: 18,
                    background: "transparent",
                    border: "1px solid #C9C2B4",
                    padding: "9px 16px",
                    fontSize: 13,
                    borderRadius: 4,
                    cursor: "pointer",
                  }}
                >
                  Submit another card
                </button>
              </div>
            )}
          </div>
        </div>
      </section>

      {/* COMPLIANCE STRIP */}
      <section
        style={{
          borderTop: "1px solid #2C3339",
          borderBottom: "1px solid #2C3339",
          padding: "20px",
        }}
      >
        <div
          style={{
            maxWidth: 1100,
            margin: "0 auto",
            display: "flex",
            justifyContent: "space-between",
            flexWrap: "wrap",
            gap: 12,
            alignItems: "center",
          }}
        >
          <span className="body-f" style={{ fontSize: 13, color: "#8A97A0" }}>
            {countError
              ? "Live count unavailable right now."
              : `${monthCount === null ? "—" : monthCount} CARE cards submitted so far in ${monthLabel()}.`}
          </span>
          <span className="mono" style={{ fontSize: 12, color: "#6B7580" }}>
            Due before end of month · every role, every month
          </span>
        </div>
      </section>

      {/* FOOTER */}
      <footer style={{ padding: "24px 20px 40px", maxWidth: 1100, margin: "0 auto" }}>
        <p className="body-f" style={{ fontSize: 12, color: "#6B7580" }}>
          BFI HSSE — OSS Section. Questions about your CARE card? Contact{" "}
          <span style={{ color: "#9AA5AC" }}>{HSSE_EMAIL}</span>.
        </p>
      </footer>
    </div>
  );
}

const inputStyle = {
  width: "100%",
  padding: "10px 12px",
  border: "1px solid #C9C2B4",
  borderRadius: 6,
  fontSize: 14,
  background: "#fff",
  color: "#1B2024",
};

function StepNav({ onBack, onNext, nextDisabled, nextLabel = "Next →", first }) {
  return (
    <div style={{ display: "flex", justifyContent: first ? "flex-end" : "space-between", marginTop: 20 }}>
      {!first && (
        <button
          onClick={onBack}
          className="body-f focus-ring"
          style={{ background: "transparent", border: "none", color: "#6B7580", fontSize: 13, cursor: "pointer" }}
        >
          ← Back
        </button>
      )}
      <button
        onClick={onNext}
        disabled={nextDisabled}
        className="body-f focus-ring"
        style={{
          background: nextDisabled ? "#C9C2B4" : "#1B2024",
          color: "#fff",
          border: "none",
          padding: "10px 18px",
          borderRadius: 6,
          fontSize: 13,
          fontWeight: 600,
          cursor: nextDisabled ? "not-allowed" : "pointer",
        }}
      >
        {nextLabel}
      </button>
    </div>
  );
}

function ReviewRow({ label, value, accent, block }) {
  return (
    <div style={{ marginBottom: 10 }}>
      <div className="mono" style={{ fontSize: 10, color: "#8A8375", textTransform: "uppercase" }}>
        {label}
      </div>
      <div
        className="body-f"
        style={{
          fontSize: 14,
          fontWeight: block ? 400 : 600,
          color: accent || "#1B2024",
          whiteSpace: block ? "pre-wrap" : "normal",
        }}
      >
        {value}
      </div>
    </div>
  );
}
