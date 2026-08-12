function hash = sha256_file(filePath)
%SHA256_FILE Return the uppercase SHA-256 digest of one file.

arguments
    filePath (1, 1) string
end
if ~isfile(filePath)
    error('laser_analysis:SourceNotFound', ...
        'Cannot hash missing file: %s', filePath);
end
digest = java.security.MessageDigest.getInstance('SHA-256');
% FileInputStream.read(byte[]) may update a temporary Java copy rather than
% the MATLAB int8 buffer on recent releases. Hash the Java byte array
% returned by Files.readAllBytes so the digest always sees the file data.
javaFile = java.io.File(char(filePath));
fileBytes = java.nio.file.Files.readAllBytes(javaFile.toPath());
bytes = typecast(digest.digest(fileBytes), 'uint8');
hash = upper(string(join(compose('%02x', bytes), '')));
end
