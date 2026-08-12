function [fitresult, gof] = fit_sine_linear(t_data, y_data, T_guess)
% FIT_SINE_LINEAR 升级版：支持 A*sin(omega*t + phi) + x*t + b
% 输入: T_guess 为预估周期

    t_data = t_data(:);
    y_data = y_data(:);

    % 1. 定义拟合模型 (参数按字母排序：A, b, omega, phi, x)
    % MATLAB 内部会自动按字母顺序对 StartPoint 进行赋值
    ft = fittype('A*sin(omega*t + phi) + x*t + b', ...
                 'independent', 't', 'dependent', 'y');

    % 2. 启发式初始值估算 (Heuristic Initialization)
    % 先粗略估计线性部分，以便更准地提取正弦部分
    p_linear = polyfit(t_data, y_data, 1);
    x_init = p_linear(1); % 斜率
    b_init = p_linear(2); % 截距
    
    % 减去线性趋势后估算幅度
    detrended_y = y_data - (x_init * t_data + b_init);
    A_init = (max(detrended_y) - min(detrended_y)) / 2;
    
    omega_init = 2 * pi / T_guess;
    phi_init = 0; % 相位通常从 0 开始迭代即可

    % 3. 配置拟合选项
    opts = fitoptions('Method', 'NonlinearLeastSquares');
    
    % 注意：StartPoint 数组顺序必须严格对应参数名的字母顺序：
    % A(1), b(2), omega(3), phi(4), x(5)
    opts.StartPoint = [A_init, b_init, omega_init, phi_init, x_init];
    
    % 适当放宽相位范围
    opts.Lower = [-Inf, -Inf, 0, -2*pi, -Inf];
    opts.Upper = [Inf, Inf, Inf, 2*pi, Inf];

    % 4. 执行拟合
    [fitresult, gof] = fit(t_data, y_data, ft, opts);
end