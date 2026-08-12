summaryFile = 'F:\01_Laser\code\catalog\matlab_validation_summary.txt';
fid = fopen(summaryFile, 'w');
cleanup = onCleanup(@() fclose(fid));

try
    repoRoot = 'F:\01_Laser\code\matlab\laser_analysis';
    cd(repoRoot);
    paths = setup_laser_analysis();
    assert(strcmp(paths.codeRoot, repoRoot), ...
        'setup_laser_analysis returned an unexpected code root.');

    results = runtests('tests');
    passed = sum([results.Passed]);
    failed = sum([results.Failed]);
    incomplete = sum([results.Incomplete]);

    fprintf(fid, 'STATUS=');
    if failed == 0 && incomplete == 0
        fprintf(fid, 'PASS\n');
    else
        fprintf(fid, 'FAIL\n');
    end
    fprintf(fid, 'TOTAL=%d\n', numel(results));
    fprintf(fid, 'PASSED=%d\n', passed);
    fprintf(fid, 'FAILED=%d\n', failed);
    fprintf(fid, 'INCOMPLETE=%d\n', incomplete);
    fprintf(fid, 'CODE_ROOT=%s\n', paths.codeRoot);
    disp(results);

    assert(failed == 0 && incomplete == 0, ...
        'MATLAB unit tests did not all pass.');
catch exception
    fprintf(fid, 'STATUS=ERROR\n');
    fprintf(fid, 'IDENTIFIER=%s\n', exception.identifier);
    fprintf(fid, 'MESSAGE=%s\n', exception.message);
    rethrow(exception);
end
