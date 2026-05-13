function matrix = clampMatrix(matrix, lower, higher)
    matrix(matrix>higher)=higher;
    matrix(matrix<lower)=lower;
end

