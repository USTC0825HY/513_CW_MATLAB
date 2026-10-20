function varargout = inputdlg(varargin) %#ok<STOUT>
% Platform batch tasks require all choices in the request.
error('cw513:platform:DialogForbidden', ...
    'MATLAB dialog inputdlg was requested. Provide the missing choice in the platform task.');
end
