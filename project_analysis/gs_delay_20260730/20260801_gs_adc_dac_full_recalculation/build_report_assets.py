from pathlib import Path
import json
import shutil

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from PIL import Image, ImageOps, ImageDraw


BUNDLE = Path(__file__).resolve().parent
FIG = BUNDLE / "Report_Figures"
FIG.mkdir(exist_ok=True)

plt.rcParams["font.sans-serif"] = ["Microsoft YaHei", "SimHei", "Arial"]
plt.rcParams["axes.unicode_minus"] = False
COLORS = {"X1G": "#2F5597", "X2G": "#C55A11", "X3G": "#548235", "X4G": "#7030A0"}


def read_csv(path):
    with path.open("r", encoding="utf-8-sig", newline="") as stream:
        return pd.read_csv(stream)


def write_csv(frame, path):
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        frame.to_csv(stream, index=False)


def read_sfdr() -> pd.DataFrame:
    frames = []
    for channel in ("X1G", "X2G", "X3G", "X4G"):
        path = BUNDLE / "SFDR" / channel / "ADC_SFDR_summary.csv"
        frame = read_csv(path)
        frame.insert(0, "Channel", channel)
        frame["FrequencyMHz"] = frame["FundamentalFrequencyHz"] / 1e6
        frame["Pass"] = frame["SFDR"] > 65.0
        frame["TestCondition"] = np.where(
            frame["FileName"].str.contains("2VPP", case=False, regex=False),
            "2 Vpp",
            "Nominal 6 dBm",
        )
        frames.append(frame)
    result = pd.concat(frames, ignore_index=True)
    write_csv(result, BUNDLE / "SFDR" / "SFDR_all_channels_summary.csv")
    return result


def plot_sfdr(frame: pd.DataFrame) -> None:
    fig, ax = plt.subplots(figsize=(9.2, 5.2), dpi=180)
    for channel, group in frame.groupby("Channel"):
        nominal = group[group["TestCondition"] == "Nominal 6 dBm"].sort_values("FrequencyMHz")
        ax.plot(
            nominal["FrequencyMHz"],
            nominal["SFDR"],
            marker="o",
            linewidth=1.8,
            markersize=5,
            color=COLORS[channel],
            label=channel,
        )
        special = group[group["TestCondition"] != "Nominal 6 dBm"]
        if not special.empty:
            ax.scatter(
                special["FrequencyMHz"],
                special["SFDR"],
                marker="s",
                facecolors="none",
                edgecolors=COLORS[channel],
                s=60,
                linewidth=1.5,
                label=f"{channel}（2 Vpp）",
            )
    ax.axhline(65, color="#C00000", linestyle="--", linewidth=1.3, label="指标：>65 dB")
    failed = frame[(~frame["Pass"]) & (frame["TestCondition"] == "Nominal 6 dBm")]
    for _, row in failed.iterrows():
        ax.annotate(
            f"{row.Channel} {row.SFDR:.2f} dB",
            (row.FrequencyMHz, row.SFDR),
            xytext=(-8, -18),
            textcoords="offset points",
            fontsize=8,
            color="#C00000",
        )
    ax.set_xlabel("输入频率（MHz）")
    ax.set_ylabel("SFDR（dB）")
    ax.set_title("AD9245四通道SFDR复算结果")
    ax.set_xticks([1, 5, 7.5, 10])
    ax.grid(True, alpha=0.28)
    ax.legend(ncol=3, fontsize=8)
    fig.tight_layout()
    fig.savefig(FIG / "01_AD9245_SFDR_summary.png", bbox_inches="tight")
    plt.close(fig)


def make_worst_spectrum_grid(frame: pd.DataFrame) -> None:
    images = []
    labels = []
    for channel in ("X1G", "X2G", "X3G", "X4G"):
        group = frame[(frame["Channel"] == channel) & (frame["TestCondition"] == "Nominal 6 dBm")]
        worst = group.loc[group["SFDR"].idxmin()]
        stem = Path(worst["FileName"]).stem
        image_path = BUNDLE / "SFDR" / channel / f"{stem}_spectrum.png"
        image = Image.open(image_path).convert("RGB")
        image.thumbnail((1150, 650))
        images.append(image.copy())
        labels.append(f"{channel}: {worst['FrequencyMHz']:.3f} MHz, SFDR={worst['SFDR']:.2f} dB")

    cell_w = max(i.width for i in images)
    cell_h = max(i.height for i in images) + 50
    canvas = Image.new("RGB", (cell_w * 2, cell_h * 2), "white")
    draw = ImageDraw.Draw(canvas)
    for idx, (image, label) in enumerate(zip(images, labels)):
        x = (idx % 2) * cell_w
        y = (idx // 2) * cell_h
        canvas.paste(image, (x + (cell_w - image.width) // 2, y))
        draw.text((x + 18, y + cell_h - 42), label, fill="black")
    canvas.save(FIG / "02_AD9245_worst_spectra_grid.png", quality=95)


def plot_bandwidth():
    frame = read_csv(BUNDLE / "Bandwidth" / "ADC_bandwidth_summary.csv")
    bandwidth = float(frame["Bandwidth3dBHz"].dropna().iloc[0])
    valid = frame["ValidForBandwidth"].astype(bool)
    fig, axes = plt.subplots(2, 1, figsize=(9.2, 7.4), dpi=180, sharex=True)
    axes[0].semilogx(frame.loc[valid, "FrequencyHz"], frame.loc[valid, "CodePp"], "o-", color="#2F5597")
    axes[0].semilogx(frame.loc[~valid, "FrequencyHz"], frame.loc[~valid, "CodePp"], "x", color="#C00000", ms=8)
    axes[0].set_ylabel("拟合 Code_pp（LSB）")
    axes[0].set_title("X3G输入频率响应")
    axes[0].grid(True, which="both", alpha=0.25)
    axes[0].legend(["有效测点", "拟合异常点"], loc="best")

    axes[1].semilogx(frame.loc[valid, "FrequencyHz"], frame.loc[valid, "RelativeDb"], "o-", color="#548235")
    axes[1].axhline(-3, color="#C00000", linestyle="--", label="−3 dB")
    axes[1].axvline(bandwidth, color="#C00000", linestyle=":", label=f"带宽 {bandwidth/1e6:.3f} MHz")
    axes[1].set_xlabel("输入频率（Hz）")
    axes[1].set_ylabel("相对幅度（dB）")
    axes[1].grid(True, which="both", alpha=0.25)
    axes[1].legend(loc="best")
    fig.tight_layout()
    fig.savefig(FIG / "03_AD9245_bandwidth.png", bbox_inches="tight")
    plt.close(fig)
    return frame, bandwidth


def plot_isolation() -> pd.DataFrame:
    frame = read_csv(BUNDLE / "Isolation" / "ADC_isolation_summary.csv")
    labels = [f"{a}→{b}" for a, b in zip(frame["DrivenChannel"], frame["QuietChannel"])]
    fig, ax = plt.subplots(figsize=(8.2, 4.8), dpi=180)
    bars = ax.bar(labels, frame["IsolationDb"], color=["#4472C4", "#70AD47", "#5B9BD5"])
    ax.axhline(40, color="#C00000", linestyle="--", label="指标：≥40 dB")
    for bar, value in zip(bars, frame["IsolationDb"]):
        ax.text(bar.get_x() + bar.get_width() / 2, value + 2, f"{value:.2f}", ha="center", fontsize=9)
    ax.set_ylabel("隔离度（dB）")
    ax.set_title("AD9245通道隔离度（X3G输入1 MHz、7 dBm）")
    ax.set_ylim(0, max(frame["IsolationDb"]) + 18)
    ax.grid(True, axis="y", alpha=0.25)
    ax.legend(loc="upper right")
    fig.tight_layout()
    fig.savefig(FIG / "04_AD9245_isolation.png", bbox_inches="tight")
    plt.close(fig)
    return frame


def plot_power_scale():
    frame = read_csv(BUNDLE / "PowerScale" / "ADC_power_scale_summary.csv")
    slope = float(frame["CalibrationSlopeDbPerDbm"].iloc[0])
    intercept = float(frame["CalibrationInterceptDb"].iloc[0])
    r2 = float(frame["CalibrationR2"].iloc[0])
    included = frame["CalibrationIncluded"].astype(bool)
    clipping = frame["ClippingFlag"].astype(bool)
    plateau = frame["PlateauFlag"].astype(bool)

    fig, axes = plt.subplots(2, 1, figsize=(9.2, 7.6), dpi=180, sharex=True)
    axes[0].plot(frame["InputPowerDbm"], frame["CodePp"], "o-", color="#2F5597", label="实测")
    axes[0].scatter(frame.loc[plateau, "InputPowerDbm"], frame.loc[plateau, "CodePp"], marker="s", facecolors="none", edgecolors="#ED7D31", s=70, label="重复/平台")
    axes[0].scatter(frame.loc[clipping, "InputPowerDbm"], frame.loc[clipping, "CodePp"], marker="x", color="#C00000", s=70, label="削顶")
    axes[0].set_ylabel("拟合 Code_pp（LSB）")
    axes[0].set_title("X3G输入功率响应（1 MHz）")
    axes[0].grid(True, alpha=0.25)
    axes[0].legend(loc="upper left", ncol=3)

    xfit = np.linspace(-10, 6, 200)
    axes[1].plot(frame["InputPowerDbm"], frame["CodeRmsDbfs"], "o-", color="#548235", label="实测")
    axes[1].plot(xfit, slope * xfit + intercept, "--", color="#C00000", label="有效点线性拟合")
    axes[1].scatter(frame.loc[~included, "InputPowerDbm"], frame.loc[~included, "CodeRmsDbfs"], facecolors="none", edgecolors="#ED7D31", s=65, label="未参与标定")
    axes[1].axvspan(-10, 6, color="#D9EAD3", alpha=0.22, label="规定摸底范围")
    axes[1].set_xlabel("信号源设置功率（dBm）")
    axes[1].set_ylabel("ADC RMS幅度（dBFS）")
    axes[1].grid(True, alpha=0.25)
    axes[1].legend(loc="upper left", ncol=2)
    axes[1].text(
        0.98,
        0.05,
        f"斜率={slope:.6f} dB/dBm\n截距={intercept:.6f} dBFS\nR^2={r2:.8f}",
        transform=axes[1].transAxes,
        ha="right",
        va="bottom",
        bbox={"facecolor": "white", "edgecolor": "#808080", "alpha": 0.9},
    )
    fig.tight_layout()
    fig.savefig(FIG / "05_AD9245_power_scale.png", bbox_inches="tight")
    plt.close(fig)
    return frame, {"slope": slope, "intercept": intercept, "r2": r2}


def copy_ad766_figures():
    linearity = read_csv(BUNDLE / "AD766_Linearity" / "AD766_linearity_summary.csv")
    noise = read_csv(BUNDLE / "AD766_Noise" / "AD766_noise_summary.csv")
    shutil.copy2(
        BUNDLE / "AD766_Linearity" / "AD766_X9_linearity_result.png",
        FIG / "06_AD766_X9_linearity.png",
    )
    shutil.copy2(
        BUNDLE / "AD766_Noise" / "AD766_noise_6V_7FFF_DC.png",
        FIG / "07_AD766_noise_6V_7FFF_DC.png",
    )
    shutil.copy2(
        BUNDLE / "AD766_Noise" / "AD766_noise_CODE_8000_DC.png",
        FIG / "08_AD766_noise_CODE_8000_DC.png",
    )
    return linearity, noise


def write_anomalies() -> None:
    rows = [
        ["Power_Scale_1MHz/-2dBm.ila.csv", "与-5dBm.csv的SHA-256完全一致", "重复文件，不参与正式标定"],
        ["Power_Scale_1MHz/6dBm.csv", "与5dBm.csv的SHA-256完全一致", "无法据此确认5～6 dBm饱和边界"],
        ["freq_scale/X3G/5MHz.ila.csv", "正弦拟合R²约1.0e-6", "不参与−3 dB带宽计算"],
        ["freq_scale/X3G/10MHz.csv", "正弦拟合R²=0.524646", "不参与−3 dB带宽计算；采用10Mhz_1.csv"],
        ["SFDR/X1G、X2G、X3G 10 MHz", "SFDR分别为64.660、63.014、64.914 dB", "低于>65 dB指标"],
        ["隔离度安静通道", "拟合R²为0.00015～0.00076", "同频分量低于单码，数值受噪声底限制"],
        ["AD766/NOISE", "CSV采样率约416.67 kSPS", "原脚本4.17 MHz硬编码不可用于本批数据"],
    ]
    write_csv(
        pd.DataFrame(rows, columns=["DataOrItem", "Observation", "Disposition"]),
        BUNDLE / "anomaly_summary.csv",
    )


def main() -> None:
    sfdr = read_sfdr()
    plot_sfdr(sfdr)
    make_worst_spectrum_grid(sfdr)
    bandwidth_frame, bandwidth_hz = plot_bandwidth()
    isolation = plot_isolation()
    power_frame, power_fit = plot_power_scale()
    linearity, noise = copy_ad766_figures()
    write_anomalies()

    summary = {
        "raw_csv_count": 49,
        "ad9245_sfdr_file_count": int(len(sfdr)),
        "sfdr_fail_count_nominal": int(((sfdr["SFDR"] <= 65) & (sfdr["TestCondition"] == "Nominal 6 dBm")).sum()),
        "bandwidth_3db_hz": bandwidth_hz,
        "bandwidth_invalid_files": bandwidth_frame.loc[
            ~bandwidth_frame["ValidForBandwidth"].astype(bool), "FileName"
        ].tolist(),
        "isolation_min_db": float(isolation["IsolationDb"].min()),
        "power_calibration": power_fit,
        "power_duplicate_pairs": [
            ["-2dBm.ila.csv", "-5dBm.csv"],
            ["6dBm.csv", "5dBm.csv"],
        ],
        "ad766_linearity_max_abs_residual_v": float(linearity["MaximumAbsoluteResidualV"].iloc[0]),
        "ad766_noise": noise.to_dict(orient="records"),
    }
    (BUNDLE / "analysis_summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
