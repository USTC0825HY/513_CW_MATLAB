"""Parse, validate, plot, and export Rohde & Schwarz FSPN CSV data."""

from __future__ import annotations

import csv
import warnings
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


def _read_csv_rows(filename):
    path = Path(filename)
    if not path.is_file():
        raise FileNotFoundError(f"FSPN data file does not exist: {path}")
    with path.open("r", encoding="utf-8-sig", newline="") as stream:
        return path, list(csv.reader(stream))


def _is_db_unit(unit):
    return "db" in unit.lower()


def _requires_positive_y(unit):
    normalized = unit.lower().replace(" ", "")
    return "sqrt" in normalized or "allan" in normalized


def parse_fspn_window(filename, target_window="3", skip_traces=None):
    """Parse one FSPN window and return validated trace data plus metadata."""
    path, rows = _read_csv_rows(filename)
    target_window = str(target_window)
    skip_traces = set(skip_traces or [])
    traces = {}
    current_window = None
    current_trace = None
    current_x_unit = ""
    current_y_unit = ""
    window_name = ""
    found_target = False
    row_index = 0

    while row_index < len(rows):
        row = rows[row_index]
        key = row[0].strip() if row else ""

        if key == "Window":
            if len(row) < 2:
                raise ValueError(f"Malformed Window row {row_index + 1} in {path}")
            next_window = row[1].strip()
            if found_target and next_window != target_window:
                break
            current_window = next_window
            if current_window == target_window:
                found_target = True
                window_name = row[2].strip() if len(row) > 2 else ""
            current_trace = None

        elif current_window == target_window:
            if key == "Trace":
                current_trace = int(row[1]) if len(row) > 1 and row[1].strip().isdigit() else None
                current_x_unit = ""
                current_y_unit = ""
            elif key == "x-Unit" and len(row) > 1:
                current_x_unit = row[1].strip()
            elif key == "y-Unit" and len(row) > 1:
                current_y_unit = row[1].strip()
            elif key == "Values":
                if len(row) < 2 or not row[1].strip().isdigit():
                    raise ValueError(f"Malformed Values row {row_index + 1} in {path}")
                value_count = int(row[1])
                data_end = row_index + 1 + value_count
                if data_end > len(rows):
                    raise ValueError(
                        f"Trace {current_trace} declares {value_count} points, but {path} is truncated"
                    )

                if current_trace is not None and current_trace not in skip_traces:
                    x_values = []
                    y_values = []
                    for source_row, value_row in enumerate(rows[row_index + 1 : data_end], row_index + 2):
                        if len(value_row) < 2:
                            raise ValueError(f"Missing x/y value at row {source_row} in {path}")
                        try:
                            x_values.append(float(value_row[0]))
                            y_values.append(float(value_row[1]))
                        except ValueError as exc:
                            raise ValueError(f"Non-numeric x/y value at row {source_row} in {path}") from exc

                    x_values = np.asarray(x_values, dtype=float)
                    y_values = np.asarray(y_values, dtype=float)
                    valid = np.isfinite(x_values) & np.isfinite(y_values) & (x_values > 0)
                    if _requires_positive_y(current_y_unit):
                        invalid_y = y_values <= 0
                        if np.any(invalid_y):
                            warnings.warn(
                                f"{path.name}, Window {target_window}, Trace {current_trace}: "
                                f"discarding {np.count_nonzero(invalid_y)} non-positive values "
                                f"declared as {current_y_unit}",
                                RuntimeWarning,
                                stacklevel=2,
                            )
                        valid &= ~invalid_y
                    invalid_count = len(valid) - np.count_nonzero(valid)
                    if invalid_count and not (_requires_positive_y(current_y_unit) and np.any(y_values <= 0)):
                        warnings.warn(
                            f"{path.name}, Window {target_window}, Trace {current_trace}: "
                            f"discarding {invalid_count} invalid points",
                            RuntimeWarning,
                            stacklevel=2,
                        )
                    if not np.any(valid):
                        raise ValueError(f"No valid points remain in Window {target_window}, Trace {current_trace}")

                    traces[current_trace] = {
                        "x": x_values[valid],
                        "y": y_values[valid],
                        "x_unit": current_x_unit,
                        "y_unit": current_y_unit,
                    }
                row_index = data_end - 1
                current_trace = None

        row_index += 1

    if not traces:
        raise ValueError(
            f"No usable traces found in Window {target_window} of {path}; "
            "check the window number and skip_traces"
        )

    x_units = {trace["x_unit"] for trace in traces.values()}
    y_units = {trace["y_unit"] for trace in traces.values()}
    if len(x_units) != 1 or len(y_units) != 1:
        raise ValueError(
            f"Window {target_window} contains inconsistent units: x={sorted(x_units)}, y={sorted(y_units)}"
        )

    return {
        "path": path,
        "window": target_window,
        "window_name": window_name,
        "x_unit": next(iter(x_units)),
        "y_unit": next(iter(y_units)),
        "traces": traces,
    }


def _legacy_trace_data(parsed):
    return {
        trace_number: (trace["x"].tolist(), trace["y"].tolist())
        for trace_number, trace in parsed["traces"].items()
    }


def plot_fspn_window(
    parsed,
    trace_mapping=None,
    is_loglog=None,
    append_title="",
    xlim=None,
):
    """Plot parsed data, selecting the correct default scale from its unit."""
    trace_mapping = trace_mapping or {}
    y_unit = parsed["y_unit"]
    use_log_y = not _is_db_unit(y_unit) if is_loglog is None else bool(is_loglog)
    if _is_db_unit(y_unit) and use_log_y:
        warnings.warn(
            f"{y_unit} is already logarithmic; using a linear Y axis instead",
            RuntimeWarning,
            stacklevel=2,
        )
        use_log_y = False

    figure, axis = plt.subplots(figsize=(10, 6), dpi=300)
    for trace_number, trace in parsed["traces"].items():
        label = trace_mapping.get(trace_number, f"Trace {trace_number}")
        if use_log_y:
            axis.loglog(trace["x"], trace["y"], label=label, linewidth=1.5)
        else:
            axis.semilogx(trace["x"], trace["y"], label=label, linewidth=1.5)

    title = parsed["window_name"] or "FSPN data"
    title = f"{title} - Window {parsed['window']}"
    if append_title:
        title = f"{title} {append_title}"
    axis.set_title(title, fontsize=14)
    axis.set_xlabel(f"Offset Frequency ({parsed['x_unit']})", fontsize=12)
    axis.set_ylabel(f"Noise Spectrum ({y_unit})", fontsize=12)
    axis.grid(True, which="both", linestyle="--", alpha=0.6)
    if xlim is not None:
        axis.set_xlim(xlim)
    axis.legend(loc="upper right", fontsize=10)
    figure.tight_layout()
    return figure, axis


def export_fspn_window(parsed, trace_mapping=None):
    """Export validated traces to a paired-column CSV next to the source file."""
    trace_mapping = trace_mapping or {}
    trace_numbers = sorted(parsed["traces"])
    trace_text = "_".join(str(number) for number in trace_numbers)
    source = parsed["path"]
    output = source.with_name(f"{source.stem}_windows_{parsed['window']}_trace{trace_text}.csv")
    max_rows = max(len(parsed["traces"][number]["x"]) for number in trace_numbers)

    with output.open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.writer(stream)
        header = []
        for number in trace_numbers:
            trace = parsed["traces"][number]
            label = trace_mapping.get(number, f"Trace {number}")
            header.extend(
                [f"{label}_X({trace['x_unit']})", f"{label}_Y({trace['y_unit']})"]
            )
        if len(header) != len(set(header)):
            raise ValueError("Trace labels produce duplicate CSV column names; make trace_mapping unique")
        writer.writerow(header)

        for row_index in range(max_rows):
            row = []
            for number in trace_numbers:
                trace = parsed["traces"][number]
                if row_index < len(trace["x"]):
                    row.extend([trace["x"][row_index], trace["y"][row_index]])
                else:
                    row.extend(["", ""])
            writer.writerow(row)
    return output


def parse_and_plot_fspn(
    filename,
    target_window="3",
    trace_mapping=None,
    skip_traces=None,
    is_loglog=None,
    append_title="",
    xlim=None,
):
    """Backward-compatible parse-and-plot entry point."""
    parsed = parse_fspn_window(filename, target_window, skip_traces)
    plot_fspn_window(parsed, trace_mapping, is_loglog, append_title, xlim)
    plt.show()
    return _legacy_trace_data(parsed)


def parse_plot_and_export_fspn(
    filename,
    target_window="3",
    trace_mapping=None,
    skip_traces=None,
    is_loglog=None,
    append_title="",
    xlim=None,
):
    """Backward-compatible parse, validated export, and plot entry point."""
    parsed = parse_fspn_window(filename, target_window, skip_traces)
    output = export_fspn_window(parsed, trace_mapping)
    print(f"数据已成功导出至: {output}")
    plot_fspn_window(parsed, trace_mapping, is_loglog, append_title, xlim)
    plt.show()
    return _legacy_trace_data(parsed)
