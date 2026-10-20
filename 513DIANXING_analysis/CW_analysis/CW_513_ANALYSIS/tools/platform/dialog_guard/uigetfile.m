function varargout = uigetfile(varargin) %#ok<STOUT>
% Platform batch tasks require all choices in the request.
error('cw513:platform:DialogForbidden', ...
    'MATLAB dialog uigetfile was requested. Provide the missing choice in the platform task.');
end
