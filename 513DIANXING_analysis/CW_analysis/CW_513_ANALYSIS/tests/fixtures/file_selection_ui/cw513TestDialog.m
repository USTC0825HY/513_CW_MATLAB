function varargout = cw513TestDialog(varargin)
%CW513TESTDIALOG Test-only queued UI returns; never enabled in production paths.
state = getappdata(0,'cw513TestDialogs');
state.calls = state.calls + 1;
if isempty(state.queue)
    setappdata(0,'cw513TestDialogs',state);
    error('cw513:test:UnexpectedDialog','Explicit invocation unexpectedly requested UI.');
end
values = state.queue{1};
state.queue(1) = [];
setappdata(0,'cw513TestDialogs',state);
varargout = values(1:nargout);
end
