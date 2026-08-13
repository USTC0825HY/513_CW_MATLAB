% function    adc_sfdr
%%
clc;
clear; % removes all variables from the current workspace
close all; % deletes all figures whose handles are not hidden

format shortG; % Short floating-point display format
format compact; % Remove blank lines in command window output

divLine = '========================================';
bPlotFft = true; % fft plot flag

%% parameters configuration
Nfft = 128*1024;    % FFT calculation length
fs = 25e6;       % sampling frequency, 25 MHz
% fs = 8.33e6;
t = (0:Nfft-1)/fs; % time domain x axis
f = (0:Nfft/2)/Nfft*fs; % freq domain x axis, from 0 to fs/2
f = f*1e-6; % unit: MHz

opt.nhd = 8; % Maximum harmonic order to analyze (2nd ~ 6th harmonic)

dcSpan = 16; % Number of frequency bins counted as DC component
sigSpan = 16;
hdsSpan = 8;
%% locate csv file
initPath = '.\';
[fileName, pathName] = uigetfile('*.csv', 'Select file',initPath, 'MultiSelect', 'on');
% if only 1 file is selected, fileNames is just a string.
if ~iscell(fileName)
    fileName = cellstr(fileName);
end
fprintf('Selected %d files...\n', length(fileName));
% set diary
diary(fullfile(pathName, 'output.txt'));

%% process
disp(divLine);
fprintf('Start to analysis\n');
disp(divLine);
ENOB_array = zeros(1, length(fileName));
    for kk = 1: length(fileName)
        %% get adc data
        
        filePath = fullfile(pathName, fileName{kk});
        data = readmatrix(filePath);
        adc_data = data(1:Nfft,end);% adc data input
        adc_data_combine = adc_data-mean(adc_data); % Time-domain DC offset elimination

        figure(1);
        clf;
        plot(t(1:1024), adc_data(1:1024), 'LineWidth',1.2); % Plot raw time-domain sampled waveform
        title(sprintf('Time Domain Waveform - File: %s - point 1~1024', fileName{kk}), 'FontSize',16);
        xlabel('Time (s)', 'FontSize',14);
        ylabel('Amplitude (LSB)', 'FontSize',14);
        grid on;
        set(gca, 'FontSize',12);

        di = adc_data_combine'; % Transpose data to row vector format
        % Print time-domain statistical information of I channel
        fprintf('I-channel:\n\tMax = %d\tMin = %d, Mean = %.2f\n', max(di), min(di), mean(di));
        disp(divLine);

        %% Windowed FFT spectrum calculation
        window_hann = hann(Nfft)'; % Generate Hanning window to suppress spectral leakage
        data_freq = fft(di.*window_hann); % Apply window then execute FFT transform

        data_freq_db = db(data_freq); % Convert complex FFT amplitude to decibel scale
        data_freq_db = data_freq_db(1:Nfft/2+1); % Extract single-sided spectrum (0 ~ fs/2)

        data_freq_power = abs(data_freq).^2/Nfft/fs; % Normalized power spectrum
        data_freq_power = data_freq_power(1:Nfft/2+1);% Single-sided normalized power spectrum

        %% Locate fundamental tone frequency bin
        [~, sigIndex] = max(data_freq_db); % Directly search maximum peak for fundamental
        [~, sigIndexAccu] = find_accu_peak(data_freq_db, sigIndex-sigSpan, sigIndex+sigSpan); % Interpolation for sub-bin accurate frequency
        fsig = fs*(sigIndexAccu-1)/Nfft; % Calculate real input signal frequency
        fprintf('Signal Frequency = %.2f MHz\n', fsig*1e-6);

        %% Locate harmonic distortion series
        hdsIndex = (1:opt.nhd)*(sigIndexAccu-1)+1; % Formula for n-th harmonic theoretical bin
        hdsIndex = mod(hdsIndex,Nfft); % Wrap harmonic indices back to 0~Nfft spectrum range
        hdsIndexAccu = hdsIndex; % Buffer for accurate harmonic index after interpolation
        hdsdb = 1:opt.nhd; % Array to store harmonic amplitude in dB
        % hdsPwr = 1:opt.nhd; % Array to store harmonic power values
        
        % Traverse 2nd to opt.nhd harmonic for precise peak search
        for k = 2:opt.nhd
            if hdsIndex(k)>Nfft/2
                hdsIndex(k) = Nfft+2 - hdsIndex(k); % Fold frequency above fs/2 back to single-sided spectrum
            end
            % Interpolate to get accurate harmonic amplitude and index
            [hdsdb(k), hdsIndexAccu(k)] = find_accu_peak(data_freq_db, hdsIndex(k)-hdsSpan, hdsIndex(k)+hdsSpan);
            fprintf('hd[%d] = %.2f\tAccurate @ %.2f\tOrigin @ %d\n', k, hdsdb(k), hdsIndexAccu(k), hdsIndex(k));
            hdsIndex(k) = round(hdsIndexAccu(k)); % Round accurate index to integer bin
            fprintf('HD[%d]\tfrom %d to %d\n', k, hdsIndex(k)-hdsSpan, hdsIndex(k)+hdsSpan);
        end
        disp(divLine);

        %% Divide spectrum into independent bands: DC, signal, harmonic
        dcIndexRange = 1:dcSpan; % All frequency bins belonging to DC component
        
        % Calculate lower bound of fundamental tone search window, avoid overlapping DC band
        if sigIndex-sigSpan < dcSpan+1
            sigIndexLower = dcSpan+1;
        else
            sigIndexLower = sigIndex-sigSpan;
        end
        % Calculate upper bound of fundamental tone search window, avoid exceeding Nyquist frequency
        if sigIndex+sigSpan > Nfft/2+1
            sigIndexUpper = Nfft/2+1;
        else
            sigIndexUpper = sigIndex+sigSpan;
        end
        sigIndexRange = sigIndexLower:sigIndexUpper; % Full frequency bin range of fundamental tone
        
        % Generate frequency bin range for each harmonic component
        hdsIndexRange = zeros(opt.nhd-1, hdsSpan*2+1);
        for k = 2:opt.nhd
            zeropad = 0; % Zero padding count for out-of-bound frequency bins
            % Handle lower boundary overflow
            if hdsIndex(k)-hdsSpan < 1
                indexLower = 1;
                zeropad = zeropad + hdsSpan-hdsIndex(k)+1;
            else
                indexLower = hdsIndex(k)-hdsSpan;
            end % End lower bound judgment
            % Handle upper boundary overflow
            if hdsIndex(k)+hdsSpan > Nfft/2+1
                indexUpper = Nfft/2+1;
                zeropad = zeropad + hdsIndex(k)+hdsSpan-(Nfft/2+1);
            else
                indexUpper = hdsIndex(k)+hdsSpan;
            end
            hdsIndexRange(k-1,:) = [(indexLower:indexUpper) zeros(1, zeropad)];
        end % End harmonic band range loop
        hdsIndexRange = reshape(hdsIndexRange, 1, (opt.nhd-1)*(hdsSpan*2+1)); % Reshape to 1D array
        % Remove frequency bins overlapping with fundamental tone and DC band to get pure harmonic range
        hdsIndexRange = setdiff(hdsIndexRange, sigIndexRange);
        hdsIndexRange = setdiff(hdsIndexRange, dcIndexRange);
        hdsIndexRange = hdsIndexRange(hdsIndexRange>0); % Filter invalid zero indices


        %% Search maximum spurious component for SFDR calculation
        data_freq_db_spur = data_freq_db;
        data_freq_db_spur([dcIndexRange sigIndexRange Nfft/2+1]) = min(data_freq_db); % Mask DC, signal and Nyquist bin
        [~, sig_spur_Index] = max(data_freq_db_spur); % Find the largest spur in remaining spectrum

        %% Time-domain sine wave fitting to get actual signal amplitude (dBFS)
        [fitResult, gof, fitInfo] = sine_fit(di, fsig, fs); % Sine fitting function
        disp(fitResult); % Output fitting model information
        disp(gof); % Output goodness of fitting parameters
        fitParameter = coeffvalues(fitResult); % Extract fitting coefficients
        vamp = fitParameter(1); % Fitted sine wave peak amplitude
        vampdb = mag2db(vamp/32/1024); % Convert amplitude to dBFS
        % vampdb = 0;
        fprintf('Fitting Amplitude = %f (%f dBFS)\n', vamp, vampdb);
        fprintf(['Fitted peak code       = %.3f\n' ...
            'Fitted valley code     = %.3f\n' ...
            'Fitted peak average    = %.3f\n' ...
            'Fitted center code    = %.3f\n' ...
            'Fitted offset code     = %.3f\n' ...
            'Code_pp               = %.3f\n'], ...
            fitInfo.peakCode, fitInfo.valleyCode, ...
            fitInfo.peakAverageCode, fitInfo.centerCode, fitInfo.offsetCode, ...
            fitInfo.codePp);
        print(fitInfo.figureHandle, [filePath, '_sine_fit.png'], '-dpng');

        %% Plot single-sided FFT spectrum figure
        if bPlotFft
            figure('Visible', 'off'); % Temporary hidden figure buffer
            figure; % Create new visible spectrum window
            data_freq_db_fs = data_freq_db-data_freq_db(sigIndex)+vampdb; % Normalize spectrum vertical axis to dBFS
            plot(f, data_freq_db_fs, 'r'); % Plot spectrum curve in red
            set(gcf, 'Position', [100 100 1600 800], 'PaperPositionMode', 'auto'); % Set figure window size
            set(gca, 'FontSize', 16); % Set axis label font size
            title(sprintf('%s\nFreq = %.3f MHz & Amp = %.3f dBFS', fileName{kk}, fsig*1e-6, vampdb), 'FontSize', 20, 'HorizontalAlignment', 'center');
            xspace = (max(f)-min(f))/50; % X-axis margin offset
            axis([min(f)-xspace max(f)+xspace -140 0]); % Fix X/Y axis display range
            xlabel('Frequency (MHz)', 'FontSize', 20);
            ylabel('Amptitude (dBFS)', 'FontSize', 20);
            % set(gca, 'YTick', data_freq_db_c(sig_spur_Index)); % Manually set Y tick (conflicts with grid)
            grid on; % Enable background grid
            hold on;
            plot([min(f) max(f)], [data_freq_db_fs(sig_spur_Index) data_freq_db_fs(sig_spur_Index)], '--g'); % Green dash line mark max spur
            % Draw vertical marker for each harmonic component
            for k = 2:opt.nhd
                hold on;
                harmonicFreqMHz = f(hdsIndex(k));
                harmonicLevelDbfs = data_freq_db_fs(hdsIndex(k));
                labelOffsetMHz = (-1)^k * xspace * 0.7;
                labelX = min(max(harmonicFreqMHz + labelOffsetMHz, min(f)), max(f));
                labelY = min(harmonicLevelDbfs + 10 + 4*(k-2), -5);
                plot([harmonicFreqMHz harmonicFreqMHz], ...
                    [harmonicLevelDbfs+2 labelY-2], '--b');
                text(labelX, labelY, sprintf('H%d', k), 'FontSize', 13, ...
                    'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
                    'BackgroundColor', 'w', 'Margin', 1);
            end % End harmonic marker loop
        end

        %% Calculate core ADC dynamic performance metrics
        disp(divLine);
        totalPwr = sum(data_freq_power); % Total integrated spectrum power
        dcPwr = sum(data_freq_power(dcIndexRange)); % Integrated DC component power
        sigPwr = sum(data_freq_power(sigIndexRange)); % Integrated fundamental signal power
        thdPwr = sum(data_freq_power(hdsIndexRange));% Integrated total harmonic power
        nsPwr = totalPwr-dcPwr-sigPwr-thdPwr; % Raw integrated noise power
        % nsPwr = (N/2+1)/(N/2+1-length(dcIndexRange)-length(sigIndexRange))*nsPwr % Partial noise correction formula
        nsPwr = (Nfft/2+1)/(Nfft/2+1-length(dcIndexRange)-length(sigIndexRange)-length(hdsIndexRange))*nsPwr; % Full-band noise power correction

        % Theoretical formula reference for ideal ADC performance
        % SNR = 6.02*N + 1.76
        % SINAD = 6.02*ENOB + 1.76
        SNR = pow2db(sigPwr/nsPwr); % Signal-to-Noise Ratio
        % SINAD = pow2db(sigPwr/(nsPwr+thdPwr))
        SINAD = pow2db(sigPwr/(totalPwr-dcPwr-sigPwr)); % Signal-to-Noise-and-Distortion Ratio
        ENOB = (SINAD-vampdb-1.76)/6.02; % Effective Number of Bits with amplitude correction
        %ENOB=(SINAD-1.763+20*log10(FSR/(2*vamp)))/6.02; % Alternative ENOB calculation formula
        SFDR = data_freq_db(sigIndex)-data_freq_db(sig_spur_Index); % Spurious-Free Dynamic Range
        ENOB_array(kk) = ENOB; % Save ENOB result of current file
        THD = pow2db(sigPwr/thdPwr); % Total Harmonic Distortion

        % Combine all metrics into text string for figure display
        resultStr = sprintf(['SFDR  = %6.2f dB\n' ...
            'SNR   = %6.2f dB\n' ...
            'SINAD = %6.2f dB\n' ...
            'THD   = %6.2f dB\n' ...
            'ENOB  = %6.2f bit\n'], ...
            SFDR, SNR, SINAD, THD, ENOB);
        fprintf('SFDR  = %6.2f\nSNR   = %6.2f\nSINAD = %6.2f\nTHD = %6.2f\nENOB  = %6.2f\n', SFDR, SNR, SINAD, THD, ENOB);

        % val_snr   = snr(adc_data_combine, fs);
        % val_sinad = sinad(adc_data_combine, fs);
        % val_sfdr  = sfdr(adc_data_combine, fs);
        % val_thd   = thd(adc_data_combine, fs);
        % val_enob  = (val_sinad - 1.76) / 6.02;
        % 
        % fprintf('SFDR  = %6.2f\nSNR   = %6.2f\nSINAD = %6.2f\nTHD = %6.2f\nENOB  = %6.2f\n', val_sfdr, val_snr, val_sinad, val_thd, val_enob);
        
        if bPlotFft
            % Mark the two tones used by the SFDR calculation.
            signalLevelDbfs = data_freq_db_fs(sigIndex);
            spurLevelDbfs = data_freq_db_fs(sig_spur_Index);
            signalFreqMHz = f(sigIndex);
            spurFreqMHz = f(sig_spur_Index);

            plot(signalFreqMHz, signalLevelDbfs, 'ko', 'MarkerFaceColor', 'y', 'MarkerSize', 8);
            plot(spurFreqMHz, spurLevelDbfs, 'ko', 'MarkerFaceColor', 'c', 'MarkerSize', 8);
            plot([spurFreqMHz spurFreqMHz], [spurLevelDbfs signalLevelDbfs], ':k', 'LineWidth', 1.5);

            text(signalFreqMHz, signalLevelDbfs - 5, ...
                sprintf('基波\n%.3f MHz\n%.2f dBFS', signalFreqMHz, signalLevelDbfs), ...
                'FontSize', 13, 'FontWeight', 'bold', 'Color', [0.35 0.15 0], ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
                'BackgroundColor', 'w', 'Margin', 1);
            text(spurFreqMHz, spurLevelDbfs - 5, ...
                sprintf('最大杂散\n%.3f MHz\n%.2f dBFS', spurFreqMHz, spurLevelDbfs), ...
                'FontSize', 13, 'FontWeight', 'bold', 'Color', [0 0.35 0.35], ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
            text(0.42 * max(f), spurLevelDbfs + 3, ...
                sprintf('SFDR = %.2f dB', SFDR), 'FontSize', 16, ...
                'FontWeight', 'bold', 'Color', [0 0.45 0], ...
                'HorizontalAlignment', 'center', 'BackgroundColor', 'w', ...
                'Margin', 3);
            text(0.76, 0.98, resultStr, 'Units', 'normalized', ...
                'FontSize', 15, 'FontWeight', 'bold', 'Color', 'b', ...
                'VerticalAlignment', 'top', 'BackgroundColor', 'w', ...
                'EdgeColor', [0.2 0.2 0.2], 'Margin', 6);
            % Code_pp annotation is intentionally disabled on the FFT spectrum figure.
            % text(0.76, 0.56, sprintf('Code_{pp} = %.3f code', fitInfo.codePp), ...
            %     'Units', 'normalized', 'FontSize', 16, 'FontWeight', 'bold', ...
            %     'Color', 'r', 'BackgroundColor', 'w', 'EdgeColor', 'r', ...
            %     'Margin', 4);
            print(gcf, [filePath, '.png'], '-dpng'); % Export spectrum as PNG image
            saveas(gcf, [filePath, '.fig']); % Save editable figure file
        end
        % clf; % Clear current figure canvas
    end % end for
disp(divLine);
sort(ENOB_array) % Sort all ENOB values from batch files
diary off; % Close log file recording
% end %end function
