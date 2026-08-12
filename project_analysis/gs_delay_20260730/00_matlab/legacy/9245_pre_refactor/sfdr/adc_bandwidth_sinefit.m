function results = adc_bandwidth_sinefit(varargin)
%ADC_BANDWIDTH_SINEFIT Backward-compatible bandwidth-analysis wrapper.
%   RESULTS = ADC_BANDWIDTH_SINEFIT runs the bandwidth task through
%   adc_analysis_main. The preferred entry point is
%   adc_analysis_main('bandwidth').

results = adc_analysis_main('bandwidth', varargin{:});
end
