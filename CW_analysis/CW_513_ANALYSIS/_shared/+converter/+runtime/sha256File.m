function hashText = sha256File(filePath)
%SHA256FILE Calculate an uppercase SHA-256 hash using binary file chunks.

fileId = fopen(filePath, 'rb');
if fileId < 0
    error('converter:runtime:CannotOpenFile', ...
        '无法打开文件进行 SHA-256 计算：%s', filePath);
end
cleanupObject = onCleanup(@() fclose(fileId));
digest = java.security.MessageDigest.getInstance('SHA-256');
while true
    byteChunk = fread(fileId, 1024 * 1024, '*uint8');
    if isempty(byteChunk)
        break;
    end
    digest.update(byteChunk);
end
hashBytes = typecast(digest.digest(), 'uint8');
hashText = upper(reshape(dec2hex(hashBytes, 2).', 1, []));
end
