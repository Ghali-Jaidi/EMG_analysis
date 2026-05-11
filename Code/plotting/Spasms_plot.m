fig = openfig('emg_corr_3.fig');  % Open saved figure

hold on
hSpasm  = plot(NaN, NaN, 's', 'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k');   % green
hNormal = plot(NaN, NaN, 's', 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');   % white with black edge
lgd = legend([hSpasm, hNormal], {'Spasm', 'Normal gait'}, 'Location', 'best');
hold off

saveas(fig, 'cross_correlation.fig');
