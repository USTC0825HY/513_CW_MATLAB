"""dBm、Vrms 和 Vpp 相互转换的图形化工具。

Vpp 与 Vrms 的换算基于正弦波，功率按纯电阻负载计算。
"""

from __future__ import annotations

import math
import tkinter as tk
from tkinter import messagebox, ttk


DEFAULT_IMPEDANCE = 50.0


def from_dbm(dbm: float, impedance: float) -> tuple[float, float, float]:
    """返回 (dBm, Vrms, Vpp)。"""
    _validate_impedance(impedance)
    power_watts = 10 ** (dbm / 10.0) / 1000.0
    vrms = math.sqrt(power_watts * impedance)
    return dbm, vrms, 2.0 * math.sqrt(2.0) * vrms


def from_vrms(vrms: float, impedance: float) -> tuple[float, float, float]:
    """返回 (dBm, Vrms, Vpp)。"""
    _validate_impedance(impedance)
    if vrms <= 0:
        raise ValueError("Vrms 必须大于 0。")
    power_watts = vrms**2 / impedance
    dbm = 10.0 * math.log10(power_watts * 1000.0)
    return dbm, vrms, 2.0 * math.sqrt(2.0) * vrms


def from_vpp(vpp: float, impedance: float) -> tuple[float, float, float]:
    """返回 (dBm, Vrms, Vpp)。"""
    if vpp <= 0:
        raise ValueError("Vpp 必须大于 0。")
    vrms = vpp / (2.0 * math.sqrt(2.0))
    dbm, _, _ = from_vrms(vrms, impedance)
    return dbm, vrms, vpp


def _validate_impedance(impedance: float) -> None:
    if impedance <= 0:
        raise ValueError("负载阻抗必须大于 0 Ω。")


def format_number(value: float) -> str:
    """以适合工程计算器显示的方式格式化数字。"""
    magnitude = abs(value)
    if magnitude != 0 and (magnitude >= 1e6 or magnitude < 1e-5):
        return f"{value:.8e}"
    return f"{value:.10g}"


class ConverterApp(ttk.Frame):
    def __init__(self, master: tk.Tk) -> None:
        super().__init__(master, padding=22)
        self.master = master
        self.grid(sticky="nsew")

        master.title("dBm / Vrms / Vpp 转换器")
        master.resizable(False, False)
        master.columnconfigure(0, weight=1)
        master.rowconfigure(0, weight=1)

        self.impedance_var = tk.StringVar(value=format_number(DEFAULT_IMPEDANCE))
        self.dbm_var = tk.StringVar()
        self.vrms_var = tk.StringVar()
        self.vpp_var = tk.StringVar()
        self.status_var = tk.StringVar(value="选择一个输入量，填写数值后点击“转换”。")

        self._build_ui()
        self.dbm_entry.focus_set()
        master.bind("<Escape>", lambda _event: self.clear())

    def _build_ui(self) -> None:
        title = ttk.Label(self, text="射频功率与电压转换", font=("Microsoft YaHei UI", 16, "bold"))
        title.grid(row=0, column=0, columnspan=3, pady=(0, 16))

        ttk.Label(self, text="负载阻抗").grid(row=1, column=0, sticky="w", pady=6)
        impedance_entry = ttk.Entry(self, textvariable=self.impedance_var, width=24)
        impedance_entry.grid(row=1, column=1, sticky="ew", padx=(12, 6), pady=6)
        ttk.Label(self, text="Ω").grid(row=1, column=2, sticky="w", pady=6)

        ttk.Separator(self).grid(row=2, column=0, columnspan=3, sticky="ew", pady=10)

        self.dbm_entry = self._add_value_row(3, "功率", self.dbm_var, "dBm", "dbm")
        self._add_value_row(4, "有效值电压", self.vrms_var, "Vrms", "vrms")
        self._add_value_row(5, "峰峰值电压", self.vpp_var, "Vpp", "vpp")

        button_frame = ttk.Frame(self)
        button_frame.grid(row=6, column=0, columnspan=3, pady=(16, 10))
        ttk.Button(button_frame, text="清空", command=self.clear).pack(side="left", padx=5)
        ttk.Button(button_frame, text="退出", command=self.master.destroy).pack(side="left", padx=5)

        ttk.Label(
            self,
            textvariable=self.status_var,
            foreground="#245a85",
            wraplength=440,
            justify="left",
        ).grid(row=7, column=0, columnspan=3, sticky="w", pady=(5, 4))

        ttk.Label(
            self,
            text="说明：Vpp ↔ Vrms 按正弦波换算；功率按纯电阻负载计算。",
            foreground="#666666",
        ).grid(row=8, column=0, columnspan=3, sticky="w", pady=(4, 0))

    def _add_value_row(
        self,
        row: int,
        label: str,
        variable: tk.StringVar,
        unit: str,
        source: str,
    ) -> ttk.Entry:
        ttk.Label(self, text=label).grid(row=row, column=0, sticky="w", pady=6)
        entry = ttk.Entry(self, textvariable=variable, width=24)
        entry.grid(row=row, column=1, sticky="ew", padx=(12, 6), pady=6)
        entry.bind("<Return>", lambda _event, name=source: self.convert(name))

        control = ttk.Frame(self)
        control.grid(row=row, column=2, sticky="w", pady=6)
        ttk.Label(control, text=unit, width=6).pack(side="left")
        ttk.Button(control, text="以此转换", command=lambda name=source: self.convert(name)).pack(side="left")
        return entry

    def convert(self, source: str) -> None:
        try:
            impedance = self._read_float(self.impedance_var.get(), "负载阻抗")
            _validate_impedance(impedance)

            variables = {
                "dbm": (self.dbm_var, "dBm"),
                "vrms": (self.vrms_var, "Vrms"),
                "vpp": (self.vpp_var, "Vpp"),
            }
            variable, label = variables[source]
            value = self._read_float(variable.get(), label)

            if source == "dbm":
                dbm, vrms, vpp = from_dbm(value, impedance)
            elif source == "vrms":
                dbm, vrms, vpp = from_vrms(value, impedance)
            else:
                dbm, vrms, vpp = from_vpp(value, impedance)

            self.dbm_var.set(format_number(dbm))
            self.vrms_var.set(format_number(vrms))
            self.vpp_var.set(format_number(vpp))
            self.status_var.set(f"已按 {format_number(impedance)} Ω 负载由 {label} 完成转换。")
        except (ValueError, OverflowError) as exc:
            self.status_var.set("输入有误，请检查数值。")
            messagebox.showerror("无法转换", str(exc), parent=self.master)

    @staticmethod
    def _read_float(text: str, label: str) -> float:
        try:
            value = float(text.strip())
        except ValueError as exc:
            raise ValueError(f"请输入有效的 {label} 数值。") from exc
        if not math.isfinite(value):
            raise ValueError(f"{label} 必须是有限数值。")
        return value

    def clear(self) -> None:
        self.dbm_var.set("")
        self.vrms_var.set("")
        self.vpp_var.set("")
        self.status_var.set("已清空。请输入一个数值后点击对应的“以此转换”。")
        self.dbm_entry.focus_set()


def main() -> None:
    root = tk.Tk()
    try:
        ttk.Style(root).theme_use("vista")
    except tk.TclError:
        pass
    ConverterApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
