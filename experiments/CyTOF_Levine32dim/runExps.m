function runExps()
% Application 2: Mass Cytometry
% Dataset 1: 13-dimensional CyTOF Data
    
    % setup paths
    setup();
    for i=1:2,
       [XTr, YTr, XTe, YTe] = load_data(num2str(i));
       runEuclidean(XTr, YTr, XTe, YTe, 1, num2str(i));
       runDMLMJ(XTr, YTr, XTe, YTe, 1, num2str(i));
    end
    
    % run transfer settings
    for i=1:2,
       [XTr1, YTr1, ~, ~] = load_data(num2str(i));
       j = 2 - (i - 1);
       [~, ~, XTr2, YTr2] = load_data(num2str(j));             
       runDMLMJ(XTr1, YTr1, XTr2, YTr2, 1,  [num2str(i) '.' num2str(j)]);
       runEuclidean(XTr1, YTr1, XTr2, YTr2, 1,  [num2str(i) '.' num2str(j)]);
    end
end

function setup()
    my_path = pwd;
    cd ..
    cd ..
    addpath(genpath(pwd));
    cd(my_path);
end

function [XTr, YTr, XTe, YTe] = load_data(num)
    % load training data
    data = importdata(['data/Levine_32dim_train_strat_patient' num '.csv']);
    data = data.data;
    XTr = data(:,2:end-1)'; % the first column are indices
    YTr = data(:,end);
    
    % load test data
    data = importdata(['data/Levine_32dim_test_strat_patient' num '.csv']);
    data = data.data;
    XTe = data(:,2:end-1)'; % the first column are indices
    YTe = data(:,end);
    
    [XTr, XTe] = normalizer(XTr, XTe);
end

function runEuclidean(XTr, YTr, XTe, YTe, saved_output, num)
    best_F1 = -1;
    best_k = -1;
    min_k = 1;
    max_k = 21;
    
    % cross validation for k
    COV = cvpartition(YTr,'holdout', 0.3);
    xtr = XTr(:,COV.training); ytr = YTr(COV.training);
    xtv = XTr(:,COV.test);     ytv = YTr(COV.test);
    
    for k=min_k:max_k,
        Y_hat = knnClassifier(xtr,ytr,k,xtv);
        f1score = F1_score(ytv, Y_hat);
        if f1score > best_F1,
            best_F1 = f1score;
            best_k = k;
        end
        fprintf('.');
    end
    
    % compute the accuracy on the test set    
    Y_hat = knnClassifier(XTr, YTr, best_k, XTe);    
    F1 = F1_score(YTe, Y_hat);    
    
    fprintf('\n--------------------------------------\n');
    fprintf('Euclidean F1score=%.2f, k=%d\n', F1, best_k);
    fprintf('--------------------------------------\n');
    
    if saved_output,
        newSubFolder=sprintf('output/Euclidean/');
        if ~exist(newSubFolder, 'dir')
            mkdir(newSubFolder);
        end
        % save the output
        train_file = [newSubFolder  sprintf(['train.' num '.txt'])];
        test_file = [newSubFolder  sprintf(['test.' num '.txt'])];
        
        csvwrite(train_file, [XTr' YTr]);
        csvwrite(test_file, [XTe' YTe]);
        csvwrite([newSubFolder sprintf(['prediction.' num '.txt'])], [Y_hat, YTe]);
    end
end

function runDMLMJ(XTr, YTr, XTe, YTe, saved_output, num)   
    % initial values
    best_F1 = -Inf;
    best_d = -1;
    best_k = -1;
    min_k = 1;
    max_k = 21;
    
    % cross-validation for k
    c   = cvpartition(YTr,'holdout', 0.3);
    xtr = XTr(:,c.training); ytr = YTr(c.training);
    xtv = XTr(:,c.test);     ytv = YTr(c.test); 
    
    % configuration
    params.dim = size(XTr,1);
    
    for k=min_k:max_k,
        % learning a linear transformation       
        params.k1 = min(10, max(k, 5));
        params.k2 = min(10, max(k, 5));
        L = DMLMJ(xtr, ytr, params);
        
        for d=2:size(xtr,1),
            Y_hat = knnClassifier(L(:,1:d)'*xtr,ytr,k,L(:,1:d)'*xtv);
            f1score = F1_score(ytv, Y_hat);
            % save the best parameters
            if f1score > best_F1, 
                best_F1 = f1score;
                best_k = k;
                best_d = d;
            end;
            fprintf('.');
        end
    end
    
    % learn DMLMJ on the best parameters
    params = struct();
    params.knn = best_k;
    params.dim = best_d;
    params.k1 = min(10, max(best_k,5));
    params.k2 = min(10, max(best_k,5));
    L = DMLMJ(XTr, YTr, params);
    
    Y_hat = knnClassifier(L'*XTr,YTr,best_k,L'*XTe);
    F1 = F1_score(YTe, Y_hat);
    fprintf('\n--------------------------------------\n');
    fprintf('DMLMJ F1_score=%.2f, k = %d\n', F1, best_k);
    fprintf('--------------------------------------\n');
    
    if saved_output,
        newSubFolder=sprintf('output/DMLMJ/');
        if ~exist(newSubFolder, 'dir')
            mkdir(newSubFolder);
        end
        
        % DMLMJ uses the set of features that provifes the best F1 score
        train_file = [newSubFolder  sprintf(['train.' num '.txt'])];
        test_file = [newSubFolder  sprintf(['test.' num '.txt'])];

        csvwrite(train_file, [(L'*XTr)' YTr]);
        csvwrite(test_file, [(L'*XTe)' YTe]);
        
        % DMLMJ uses all features
        params.knn = best_k;
        params.dim = size(XTr,1);
        params.k1 = min(10, max(best_k,5));
        params.k2 = min(10, max(best_k,5));
        L = DMLMJ(XTr, YTr, params);

        train_all_file = [newSubFolder  sprintf(['train_all.' num '.txt'])];
        test_all_file = [newSubFolder  sprintf(['test_all.' num '.txt'])];
        csvwrite(train_all_file, [(L'*XTr)' YTr]);
        csvwrite(test_all_file, [(L'*XTe)' YTe]);
        csvwrite([newSubFolder sprintf(['prediction.' num '.txt'])], [Y_hat, YTe]);
    end    
end