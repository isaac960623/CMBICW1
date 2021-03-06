clear all;
close all;


clear all;
close all;
load('data');
dwis=double(dwis);
dwis=permute(dwis,[4,1,2,3]);

qhat = load('bvecs');
bvals = 1000*sum(qhat.*qhat);

[slice_length, slice_x, slice_y,~] = size(dwis);

Avox = dwis(:,92,65,72);

% Define various options for the non�linear fitting algorithm.
    h=optimset('MaxFunEvals',20000,...
   'Algorithm','quasi-newton',...
   'TolX',1e-10,...
   'Display','none',...
   'TolFun',1e-10);

% Define a starting point for the non�linear fit
x0 = [3.5e+0, 3e-03, 2.5e-01, 0, 0];

% [end_params, RESNORM] = findGlobalMin(x0,Avox,bvals,qhat,h);
end_params = zeros(slice_x,slice_y,5);

tic;
for i=1:slice_y
    for j=1:slice_x
        current_voxel = dwis(:,slice_x,slice_y,72);
        [end_param, new_res] = findGlobalMin(x0,current_voxel,bvals,qhat,h);
        [x1,x2,x3,x4,x5] = newTransform(end_param);
        end_params(j,i,:) = [x1,x2,x3,x4,x5];
    end
end
toc;

% save('q114.mat','end_params');
load('q114.mat');
createSliceMap(end_params,end_res);


function [x1, x2, x3, x4, x5] = newInverse(x)
    x1 = sqrt(x(1));
    x2 = sqrt(x(2));
    x3 = -log((1/x(3)) - 1);
    x4 = x(4);
    x5 = x(5);
end

function [x1, x2, x3, x4, x5] = newTransform(x)
    x1 = x(1)^2;
    x2 = x(2)^2;
    x3 = 1/(1+exp(-1*x(3)));
    x4 = x(4);
    x5 = x(5);
end

function [sumRes, resJ] = BallStickSSD2(x0, Avox, bvals,qhat)
    [ x1, x2, x3, x4, x5] = newTransform(x0);
    % Extract the parameters
    S0 = x1;
    diff = x2;
    f = x3;
    theta = x4;
    phi = x5;
    
    % Synthesize the signals
    fibdir = [cos(phi)*sin(theta) sin(phi)*sin(theta) cos(theta)];
    fibdotgrad = sum(qhat.*repmat(fibdir, [length(qhat) 1])');
    S = S0*(f*exp(-bvals*diff.*(fibdotgrad.^2)) + (1-f)*exp(-bvals*diff));
    
    % Compute the sum of square differences
    sumRes = sum((Avox - S').^2);
    resJ = S;
end

function [finalParams, resnorm] = findGlobalMin(x0, Avox, bvals, qhat,h)

    [x1,x2,x3,x4,x5] = newInverse(x0);
    x_inv = [x1, x2, x3, x4, x5];
    
    % Now run the fitting
    [parameter_hat,RESNORM,~,~] = fminunc(@BallStickSSD2, x_inv, h, Avox, bvals,qhat);
    global_min = RESNORM;

    num_iterations = 100;
    counter = 0;
    normalised_start = x0 + 0.0001;
    global_set = ones(1,num_iterations);
    global_params = parameter_hat;
    for i=1:num_iterations
        random_modifier = rand(size(normalised_start));
        [z1,z2,z3,z4,z5] = newInverse((normalised_start) .* random_modifier);
        random_start = [z1,z2,z3,z4,z5];
        [parameter_hat,new_res,~,~] = fminunc(@BallStickSSD2, random_start, h, Avox, bvals,qhat);
        global_set(i) = new_res;
        if (abs(new_res - global_min) <= 0.1)
            counter = counter + 1;
        elseif ((global_min - new_res) > 0.1)
            global_min = new_res;
            counter = 0;
            global_params = parameter_hat;
        end
    end
%     disp(global_min);
%     disp(counter);
    finalParams = global_params;
    resnorm = global_min;
end

function createSliceMap(params, resnorms)

    S0_params = params(:,:,1);
    diff_params = params(:,:,2);
    f_params = params(:,:,3);
    
    f = figure;
    imshow(S0_params,[min(S0_params(:)),max(S0_params(:))],'Border','tight','InitialMagnification','fit');
    saveas(f,'Diagrams/q114-S0Map.png');
    clf(f);
    
    imshow(diff_params,[1e-04,5e-03],'Border','tight','InitialMagnification','fit');
    saveas(f,'Diagrams/q114-diffMap.png');
    clf(f);
    
    imshow(f_params,[min(f_params(:)),max(f_params(:))],'Border','tight','InitialMagnification','fit');
    saveas(f,'Diagrams/q114-fMap.png');
    clf(f);
    
    imshow(resnorms,[1e04,max(resnorms(:))],'Border','tight','InitialMagnification','fit');
    saveas(f,'Diagrams/q114-resMap.png');
    clf(f);
    theta_params = params(:,:,4);
    phi_params = params(:,:,5);
    direction_x = f_params.*cos(phi_params).*sin(theta_params);
    direction_y = f_params.*sin(phi_params).*sin(theta_params);    
    
    quiver(direction_x,direction_y);
    saveas(f,'Diagrams/q114-quiverMap.png');
end