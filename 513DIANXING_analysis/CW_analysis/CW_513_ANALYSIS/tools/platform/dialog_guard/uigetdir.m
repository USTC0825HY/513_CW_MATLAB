function varargout = uigetdir(varargin) %#ok<STOUT>
% Platform batch tasks require all choices in the request.
error('cw513:platform:DialogForbidden', ...
    'MATLAB dialog uigetdir was requested. Provide the missing choice in the platform task.');
end
