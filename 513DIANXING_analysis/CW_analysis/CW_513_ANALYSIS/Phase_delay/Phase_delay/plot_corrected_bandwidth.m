function plot_corrected_bandwidth(r,folder,label)
%PLOT_CORRECTED_BANDWIDTH Show corrected phases on their own phase scale.
b=r.bode;f=figure('Visible','off','Color','w','Position',[100 100 1100 700]);
yyaxis left;hm=semilogx(b.Frequency_Hz,b.Magnitude_dB,'LineWidth',1.8);ylabel('Magnitude (dB)');
yyaxis right;hp=semilogx(b.Frequency_Hz,[b.Corrected_phase_10pct_deg b.Corrected_phase_50pct_deg],'LineWidth',1.8);
hp(1).Color=[0.85 0.33 0.1];hp(2).Color=[0.47 0.2 0.65];hp(2).LineStyle='--';
hold on;yline(-45,':','-45 deg','HandleVisibility','off');grid on;xlabel('Frequency (Hz)');ylabel('Corrected phase (deg)');
v=[b.Corrected_phase_10pct_deg;b.Corrected_phase_50pct_deg];ylim([min(-60,min(v))-5,max(10,max(v))+5]);
notes=strings(2,1);
for j=1:2
    fc=r.phase45.First_downward_minus45_Hz(j);q=r.delay.Threshold_percent(j);
    if isfinite(fc)
        plot(fc,-45,'o','Color',hp(j).Color,'MarkerFaceColor',hp(j).Color,'HandleVisibility','off');
        xline(fc,':','Color',hp(j).Color,'HandleVisibility','off');
        notes(j)=sprintf('%d%%: f(-45 deg) = %.4f MHz',q,fc/1e6);
    else
        notes(j)=sprintf('%d%%: no -45 deg crossing in scan',q);
    end
end
title(label+" | magnitude and delay-corrected phase",'Interpreter','none');subtitle(join(notes," | "));
legend([hm;hp],{'Magnitude','10% delay correction','50% delay correction'},'Location','southwest');
exportgraphics(f,fullfile(folder,'corrected_bandwidth.png'),'Resolution',180);
savefig(f,fullfile(folder,'corrected_bandwidth.fig'));close(f);
end
