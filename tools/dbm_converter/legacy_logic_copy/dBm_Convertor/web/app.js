(function () {
  "use strict";

  const SQRT_2 = Math.sqrt(2);

  function validateImpedance(impedance) {
    if (!Number.isFinite(impedance) || impedance <= 0) {
      throw new Error("负载阻抗必须大于 0 Ω。");
    }
  }

  function fromDbm(dbm, impedance) {
    validateImpedance(impedance);
    if (!Number.isFinite(dbm)) throw new Error("请输入有效的 dBm 数值。");
    const powerWatts = Math.pow(10, dbm / 10) / 1000;
    const vrms = Math.sqrt(powerWatts * impedance);
    return { dbm, vrms, vpp: 2 * SQRT_2 * vrms };
  }

  function fromVrms(vrms, impedance) {
    validateImpedance(impedance);
    if (!Number.isFinite(vrms) || vrms <= 0) throw new Error("Vrms 必须大于 0。");
    const dbm = 10 * Math.log10((vrms * vrms / impedance) * 1000);
    return { dbm, vrms, vpp: 2 * SQRT_2 * vrms };
  }

  function fromVpp(vpp, impedance) {
    validateImpedance(impedance);
    if (!Number.isFinite(vpp) || vpp <= 0) throw new Error("Vpp 必须大于 0。");
    const vrms = vpp / (2 * SQRT_2);
    return { dbm: 10 * Math.log10((vrms * vrms / impedance) * 1000), vrms, vpp };
  }

  function formatNumber(value) {
    const magnitude = Math.abs(value);
    if (magnitude !== 0 && (magnitude >= 1e6 || magnitude < 1e-5)) return value.toExponential(8);
    return Number(value.toPrecision(10)).toString();
  }

  const api = { fromDbm, fromVrms, fromVpp, formatNumber };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  if (typeof window !== "undefined") window.DbmConverter = api;
  if (typeof document === "undefined") return;

  const inputs = {
    dbm: document.querySelector("#dbm"),
    vrms: document.querySelector("#vrms"),
    vpp: document.querySelector("#vpp"),
  };
  const impedanceInput = document.querySelector("#impedance");
  const status = document.querySelector("#status");
  const statusText = document.querySelector("#status-text");
  let activeSource = "dbm";

  function setStatus(message, isError = false) {
    statusText.textContent = message;
    status.classList.toggle("error", isError);
    status.querySelector(".status-icon").textContent = isError ? "!" : "✓";
  }

  function setActive(source) {
    activeSource = source;
    document.querySelectorAll(".value-field").forEach((field) => {
      field.classList.toggle("active", field.dataset.source === source);
    });
  }

  function updatePresetState() {
    const value = Number(impedanceInput.value);
    document.querySelectorAll(".preset").forEach((button) => {
      button.classList.toggle("active", Number(button.dataset.value) === value);
    });
  }

  function convert(source = activeSource) {
    try {
      const impedance = Number(impedanceInput.value);
      const value = Number(inputs[source].value);
      if (inputs[source].value.trim() === "") throw new Error("请先输入需要换算的数值。");

      const result = source === "dbm"
        ? fromDbm(value, impedance)
        : source === "vrms"
          ? fromVrms(value, impedance)
          : fromVpp(value, impedance);

      Object.entries(result).forEach(([key, resultValue]) => {
        if (key !== source) inputs[key].value = formatNumber(resultValue);
      });
      setStatus(`当前以 ${source === "dbm" ? "dBm" : source === "vrms" ? "Vrms" : "Vpp"} 为输入，结果基于 ${formatNumber(impedance)} Ω 负载。`);
    } catch (error) {
      setStatus(error.message, true);
    }
  }

  Object.entries(inputs).forEach(([source, input]) => {
    input.addEventListener("focus", () => setActive(source));
    input.addEventListener("input", () => {
      setActive(source);
      convert(source);
    });
  });

  impedanceInput.addEventListener("input", () => {
    updatePresetState();
    convert();
  });

  document.querySelectorAll(".preset").forEach((button) => {
    button.addEventListener("click", () => {
      impedanceInput.value = button.dataset.value;
      updatePresetState();
      convert();
    });
  });

  document.querySelector("#reset-button").addEventListener("click", () => {
    impedanceInput.value = "50";
    inputs.dbm.value = "0";
    inputs.vrms.value = "";
    inputs.vpp.value = "";
    setActive("dbm");
    updatePresetState();
    convert("dbm");
    inputs.dbm.focus();
  });

  convert("dbm");
})();
