function varargout = questdlg(varargin) %#ok<STOUT>
% Platform batch tasks require all choices in the request.
error('cw513:platform:DialogForbidden', ...
    'MATLAB dialog questdlg was requested. Provide the missing choice in the platform task.');
end
