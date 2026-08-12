%% 故障复位工况DDS：纯时域硬流水仿真与1小时长期相位演变分析
% clear; clc; close all;

%% 1. 参数设置
Fs = uint64(100e6);                 % 时钟频率: 100 MHz
FPGA_DDS = uint64(0x1C36113404E8);  % 48-bit FTW
N_total = uint64(2^48);             % 48-bit 满量程
reset_interval = uint64(1e6);       % 复位周期 10 ms = 1e6 周期
reset_persist = uint64(32);         % 复位持续 32 周期
reset_to_start = uint64(10);        % 撤去后等待 10 周期

% 仿真 15 个周期用于捕捉收敛规律与绘制细节
num_periods = 15;
N_sim = num_periods * reset_interval;
stable_offset = reset_persist + reset_to_start + uint64(100); 

%% 2. 纯粹的时域无损硬流水
grid_diff_history = zeros(1, num_periods, 'uint64');
reg_acc_normal = uint64(0);
reg_acc_faulty = uint64(0);
in_reset_clear = false;

fprintf('正在执行纯时域硬件级硬流水仿真中...\n');
for t = uint64(1):N_sim
    % 正常DDS寄存器累加
    reg_acc_normal = mod(reg_acc_normal + FPGA_DDS, N_total);
    
    % 故障DDS寄存器流水驱动
    cycle_idx = mod(t - 1, reset_interval); 
    if cycle_idx < reset_persist
        if cycle_idx == 0
            in_reset_clear = false;
        end
        if in_reset_clear
            reg_acc_faulty = uint64(0);
        else
            prev_acc = reg_acc_faulty;
            reg_acc_faulty = mod(reg_acc_faulty + FPGA_DDS, N_total);
            if reg_acc_faulty < prev_acc || reg_acc_faulty == 0
                reg_acc_faulty = uint64(0);
                in_reset_clear = true; 
            end
        end
    elseif cycle_idx < (reset_persist + reset_to_start)
        reg_acc_faulty = FPGA_DDS; 
    else
        reg_acc_faulty = mod(reg_acc_faulty + FPGA_DDS, N_total); 
    end
    
    % 定时绝对抽样
    if cycle_idx == stable_offset
        p_idx = double((t - 1) / reset_interval) + 1;
        grid_diff_history(p_idx) = mod(reg_acc_normal - reg_acc_faulty, N_total);
    end
end
fprintf('仿真完成！\n');

%% 3. 高精度标度转换
phase_diff_degrees = double(grid_diff_history) * (360.0 / 2^48);
init_angle = phase_diff_degrees(1);
step_angle = phase_diff_degrees(2) - phase_diff_degrees(1);

%% 4. 宏观长时基（1小时）定量解析外推
total_hours = 1;
resets_per_second = 100;
total_resets_1hr = total_hours * 3600 * resets_per_second; % 360,000 次

% 1小时宏观抽样点
plot_points = 1000;
sample_resets = linspace(1, total_resets_1hr, plot_points);
time_hours_axis = sample_resets / (resets_per_second * 3600);

% 基于流水验证出的"零步进"规律进行精确外推
long_term_degrees = init_angle + (sample_resets - 1) * step_angle;

%% 5. 打印最终全景定量报告
fprintf('\n==================== 1小时跨度长期定量分析报告 ====================\n');
fprintf('单次复位后的绝对基波相位差     : %.12f 度\n', init_angle);
fprintf('微观相邻周期相移运动步进 (真值) : %.12f 度\n', step_angle);
fprintf('1小时内总复位触发次数          : %d 次\n', total_resets_1hr);
fprintf('------------------------------------------------------------------\n');
fprintf('【最终结论】1小时累积的真实绝对相移变化量: %.12f 度\n', step_angle * double(total_resets_1hr));
fprintf('==================================================================\n');

%% 6. 综合绘图：双时基下的终审验证趋势图
figure('Name', 'DDS全时基相位差演变分析', 'Position', [200, 200, 1000, 600]);

% 子图 1：微观时域流水抽样（横跨 150 ms）
subplot(2, 1, 1);
plot(1:num_periods, phase_diff_degrees, 'b-s', 'LineWidth', 1.5, 'MarkerFaceColor', 'b');
grid on; set(gca, 'XTick', 1:num_periods);
title('【微观视角】纯时域硬流水抓取的前 15 次复位重新稳定后的绝对相位差');
xlabel('复位次数 (Count)');
ylabel('绝对相位差 (\circ 度)');
ylim([init_angle - 5, init_angle + 5]); % 适当拉开窗口看清恒定平线

% 子图 2：宏观 1 小时长期相位演变轨迹
subplot(2, 1, 2);
plot(time_hours_axis, long_term_degrees, 'r-', 'LineWidth', 2);
grid on;
title(sprintf('【宏观视角】 排除算法截断后，该错误工况在 %d 小时内的真实相位变化轨迹', total_hours));
xlabel('时间 (Hours)');
ylabel('绝对相位差 (\circ 度)');
ylim([0, 360]);