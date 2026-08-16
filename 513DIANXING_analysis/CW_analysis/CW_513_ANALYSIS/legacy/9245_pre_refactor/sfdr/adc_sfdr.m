function results = adc_sfdr(varargin)
%ADC_SFDR Backward-compatible wrapper for the unified SFDR analysis.
%   RESULTS = ADC_SFDR runs the SFDR task through adc_analysis_main.
%   The preferred entry point is adc_analysis_main('sfdr').

results = adc_analysis_main('sfdr', varargin{:});
end
