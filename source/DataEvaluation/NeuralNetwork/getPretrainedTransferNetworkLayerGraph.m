function lgraph=getPretrainedTransferNetworkLayerGraph(network,outputLayerCount,varargin)
    % The function returns a neural network configured for transfer
    % learning with the layers defined as 'new layers' below at the end of
    % the network. The final fully connected layer, the softmax and
    % classification layer at the end of the network have outputLayerCount
    % output variables.
    %
    % Download the networks below from the mathworks homepage and save them
    % in a varaible named 'net' in a matfile with the matfile name
    % described below before using this function.
    defaultDropoutPercentage = 0.5;
    defaultWeightLearnRateFactor = 10;
    defaultBiasLearnRateFactor = 10;

    p = inputParser();
    validScalarPosNum = @(x)(isnumeric(x) && isscalar(x) && (x > 0));
    p.addOptional('dropout',defaultDropoutPercentage,validScalarPosNum);
    p.addOptional('weightLearnRateFactor',defaultWeightLearnRateFactor,validScalarPosNum);
    p.addOptional('biasLearnRateFactor',defaultBiasLearnRateFactor,validScalarPosNum);
    p.parse(varargin{:});


    path=fileparts(mfilename('fullpath'));

    newLayers=[
        dropoutLayer(p.Results.dropout,'Name','dropout')
        fullyConnectedLayer(outputLayerCount,'WeightLearnRateFactor',p.Results.weightLearnRateFactor,'BiasLearnRateFactor',p.Results.biasLearnRateFactor,'Name','fcN');
        softmaxLayer('Name','softmax')
        classificationLayer('Name','classification')];
    if ischar(network)
        switch network
            case 'alexnet'
                load([path,filesep,'alexnet.mat'],'net');
                layersToKeep=net.Layers(1:end-3);
                layers = [layersToKeep
                    newLayers];
                lgraph=layerGraph(layers);
            case 'resnet101'
                load([path,filesep,'resnet101.mat'],'net');
                lgraph = layerGraph(net);
                lgraph=lgraph.removeLayers({'fc1000','prob','ClassificationLayer_predictions'});
                lgraph=lgraph.addLayers(newLayers);
                lgraph=lgraph.connectLayers('pool5','dropout');
            case 'googlenet'
                load([path,filesep,'googlenet.mat'],'net');
                lgraph = layerGraph(net);
                lgraph=lgraph.removeLayers({'pool5-drop_7x7_s1','loss3-classifier','prob','output'});
                lgraph=lgraph.addLayers(newLayers);
                lgraph=lgraph.connectLayers('pool5-7x7_s1','dropout');
            case 'squeezenet'
                load([path,filesep,'squeezenet.mat'],'net');
                lgraph = layerGraph(net);
                lgraph=lgraph.removeLayers({'prob','ClassificationLayer_predictions'});
                lgraph=lgraph.addLayers(newLayers);
                lgraph=lgraph.connectLayers('pool10','dropout');
            case 'densenet201'
                load([path,filesep,'densenet201.mat'],'net');
                lgraph = layerGraph(net);
                lgraph=lgraph.removeLayers({'fc1000','fc1000_softmax','ClassificationLayer_fc1000'});
                lgraph=lgraph.addLayers(newLayers);
                lgraph=lgraph.connectLayers('avg_pool','dropout');
            case 'xception'
                load([path,filesep,'xception.mat'],'net');
                lgraph = layerGraph(net);
                lgraph=lgraph.removeLayers({'predictions','predictions_softmax','ClassificationLayer_predictions'});
                lgraph=lgraph.addLayers(newLayers);
                lgraph=lgraph.connectLayers('avg_pool','dropout');
            case 'nasnetlarge'
                load([path,filesep,'nasnetlarge.mat'],'net');
                lgraph = layerGraph(net);
                lgraph=lgraph.removeLayers({'predictions','predictions_softmax','ClassificationLayer_predictions'});
                lgraph=lgraph.addLayers(newLayers);
                lgraph=lgraph.connectLayers('global_average_pooling2d_2','dropout');
            otherwise
                error('unknown net')
        end
    elseif isa(network,'SeriesNetwork') || isa(network,'DAGNetwork')
        lgraph = layerGraph(network);
        connectSource=lgraph.Connections.Source(strcmp(lgraph.Connections.Destination,'dropout'));
        lgraph=lgraph.removeLayers({'dropout','fcN','softmax','classification'});
        lgraph=lgraph.addLayers(newLayers);
        lgraph=lgraph.connectLayers(connectSource,'dropout');
    else
        error('unknown datatype');
    end
end