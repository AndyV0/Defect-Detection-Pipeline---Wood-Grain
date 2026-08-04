for k = 1:size(myImages, 4)
    fprintf("Image %g \n", k)
    result(k) = inspectPart(myImages(:,:,:,k), netTransfer, classNames, true);
    fprintf("\n \n")
end