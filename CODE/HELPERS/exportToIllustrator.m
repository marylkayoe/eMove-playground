function R = exportToIllustrator( fig, filePath, fileName )
    % exports given figure to an illustrator compatible format eps 
    % setting renderer to 'painters' to avoid rasterization
    % removing the bounding boxes
    % removing the white background

    % set the renderer to 'painters' to avoid rasterization
    set(fig, 'Renderer', 'painters');
    % remove bounding boxes
 %   set(fig, 'color', 'none');
    % export to eps
    saveFileName = fullfile(filePath, fileName);
    print(gcf, '-depsc', saveFileName);

    % report the location where the file was saved with full path
    R = saveFileName;
    disp (['File saved at: ', R]);

end


