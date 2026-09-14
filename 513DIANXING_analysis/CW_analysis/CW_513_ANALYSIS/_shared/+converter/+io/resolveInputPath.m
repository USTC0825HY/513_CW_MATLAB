function filePath = resolveInputPath(dataFolder, fileName)
%RESOLVEINPUTPATH Resolve relative inputs against the declared data folder.
fileName = char(fileName);
if java.io.File(fileName).isAbsolute()
    filePath = fileName;
else
    filePath = fullfile(char(dataFolder), fileName);
end
filePath = char(java.io.File(filePath).getCanonicalPath());
end
