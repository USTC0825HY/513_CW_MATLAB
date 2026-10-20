function varargout = listdlg(varargin) %#ok<STOUT>
% Platform batch tasks require all choices in the request.
error('cw513:platform:DialogForbidden', ...
    'MATLAB dialog listdlg was requested. Provide the missing choice in the platform task.');
end
