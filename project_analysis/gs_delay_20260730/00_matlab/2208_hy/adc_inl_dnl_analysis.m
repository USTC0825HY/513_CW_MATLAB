function results = adc_inl_dnl_analysis(dataFolder, selectedFiles, ...
        outputFolder, recordsAreSampleContiguous)
%ADC_INL_DNL_ANALYSIS Analyze one folder of AD2208 sine-code-density data.
%   ADC_INL_DNL_ANALYSIS(DATAFOLDER) automatically analyzes every CSV file
%   directly below DATAFOLDER. Pass SELECTEDFILES to analyze an explicit
%   subset. Each CSV is treated as an independently triggered record.
%   Set RECORDSARESAMPLECONTIGUOUS to true only when the acquisition system
%   guarantees that the final sample of one file is immediately followed
%   by the first sample of the next file.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4, recordsAreSampleContiguous = []; end
if ~isempty(dataFolder) && isempty(selectedFiles) && isfolder(dataFolder)
    fileInfo = dir(fullfile(char(dataFolder), '*.csv'));
    selectedFiles = sort({fileInfo.name});
    if isempty(selectedFiles)
        error('ad2208:NoInlDnlCsv', ...
            'INL/DNL 数据目录中没有 CSV：%s', char(dataFolder));
    end
end
config = ad2208Config('inl_dnl');
if ~isempty(recordsAreSampleContiguous)
    if ~isscalar(recordsAreSampleContiguous) || ...
            ~(islogical(recordsAreSampleContiguous) || ...
            isnumeric(recordsAreSampleContiguous))
        error('ad2208:InvalidContinuityFlag', ...
            'recordsAreSampleContiguous 必须是逻辑标量。');
    end
    config.recordsAreSampleContiguous = logical(recordsAreSampleContiguous);
end
results = converter.adc.runInlDnl(config, ...
    dataFolder, selectedFiles, outputFolder);
end
