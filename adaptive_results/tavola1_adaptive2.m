%% Clean ENV

clear all
close all
clc

%% Choose Trajectory

fprintf('Choose trajectory: \n');

fprintf('1: Circumference \n');

fprintf('2: Helix \n');

choiche = input(' ... ');

%% Setup
 
load('robot.mat')
load('robotmodel.mat')


grey = [0.5, 0.5, 0.5];
orange = [0.8, 0.6, 0];

t_in = 0; % [s]
t_fin = 10; % [s]
delta_t = 0.001; % [s]
timeSpan= 10;

t = t_in:delta_t:t_fin;

num_of_joints = 7;

Q = zeros(num_of_joints,length(t));
dQ = zeros(num_of_joints,length(t));
ddQ = zeros(num_of_joints,length(t));
TAU = zeros(num_of_joints,length(t));

%% Select Trajectory

switch choiche
                    
    case 1 % Circonferenza
        
        q0 = [0 pi/3 0 pi/6 0 0 0];
        q_dot0 = [0 0 0 0 0 0 0];
        
        pos0 = PANDA.fkine(q0).t;

        radius = 0.1; % raggio dell'elica [m]
        center = pos0 - [radius;0;0];
        
%           Standard Trajectory
%         x = center(1) + radius * cos(t/t(end)*2*pi);
%         y = center(2) * ones(size(x));
%         z = center(3) + radius * sin(t/t(end)*2*pi);
%         theta = 0.1*sin(t/5*2*pi);
        
%         Fast Trajectory
        x = center(1) + radius * cos(t/t(end)*2*pi);
        y = center(2) * ones(size(x));
        z = center(3) + radius * sin(t/t(end)*2*pi);
        theta = 0.1*sin(t/3*2*pi);
        
        phi = zeros(size(x));
        psi = zeros(size(x));

        xi = [x; y; z; theta; phi; psi]; % twist
        
        
        q_des= generate_trajectory(xi,q0,PANDA)
        dq_des=gradient(q_des)*1000
        ddq_des=gradient(dq_des)*1000
        
        figure
        PANDA.plotopt = {'workspace',[-0.75,0.75,-0.75,0.75,0,1]};
        PANDA.plot(q0,'floorlevel',0,'linkcolor',orange,'jointcolor',grey)
        hold
        plot3(x,y,z,'k','Linewidth',1.5)
        
    case 2 % Traiettoria elicoidale
        
        q0 = [0 pi/3 0 pi/6 0 0 0];
        q_dot0 = [0 0 0 0 0 0 0];
        pos0 = PANDA.fkine(q0).t;
       
        shift = 0.1; % passo dell'elica [m] 
        radius = 0.1; % raggio dell'elica [m]
        num = 2; % numero di giri [#]
        center = pos0 - [radius;0;0];

        x = center(1) + radius * cos(t/t(end)*num*2*pi);
        y = center(2) + t/t(end)*num*shift;
        z = center(3) + radius * sin(t/t(end)*num*2*pi);
        theta = zeros(size(x));
        phi = zeros(size(x));
        psi = zeros(size(x));

        xi = [ x ;y; z; theta ;phi; psi]; % twist
        
        
        q_des= generate_trajectory(xi,q0,PANDA)
        dq_des=gradient(q_des)*1000
        ddq_des=gradient(dq_des)*1000

%         figure
%         PANDA.plot(q0)
%         hold
%         plot3(x',y',z','k','Linewidth',1.5, 'Red')


end

%% Visualize desired trajectory

figure

plot3(x,y,z,'r','Linewidth',1.5)

grid on
PANDA.plotopt = {'workspace',[-0.75,0.75,-0.75,0.75,0,1]};
hold on
for i=1:100:length(q_des)
    
    PANDA.plot(transpose(q_des(:,i)),'floorlevel',0,'fps',1000,'trail','-k','linkcolor',orange,'jointcolor',grey)

end

%% Plot Joint Trajectories


figure
for j=1:num_of_joints
    
    subplot(4,2,j);
    plot(t,q_des(j,1:length(t)))
    xlabel('time [s]');
    ylabeltext = sprintf('_%i [rad]',j);
    ylabel(['Joint position' ylabeltext]);
    grid;
end

%% Plot xyz trajectory
a=[x;y;z]
figure
for j=1:3
    
    subplot(1,3,j);
    plot(t,a(j,1:length(t)))
    xlabel('time [s]');
    ylabeltext = sprintf('_%i [rad]',j);
    ylabel(['Joint position' ylabeltext]);
    grid;
end

%% Trajectory Tracking: Computed Torque Method


% % Gain circumference parameters matrix
Kp = 20*diag([3 3 3 3 5 3 30]);
Kv = 10*diag([1 1 1 1 70 2 1]);

% Good Helix parameters matrix
% Kp = 200*diag([3 3 3 3 5 3 5]);
% Kv = 25*diag([1 1 1 1 70 2 70]);

results_computed_torque = q0;
index = 1;
q=q0
dq=q_dot0
ddq=[0 0 0 0 0 0 0]
for i=1:length(t)

   % Error and derivate of the error   
    err = transpose(q_des(:,i)) - q;
    derr = transpose(dq_des(:,i)) - dq;
    
    %Get dynamic matrices
    F = get_FrictionTorque(dq);
    G = get_GravityVector(q);
    C= get_CoriolisVector(q,dq);
    M = get_MassMatrix(q);

    % Computed Torque Controller
    
    tau = ( M*(ddq_des(:,1) + Kv*(derr') + Kp*(err')) + C + G +F)';
      
    % Robot joint accelerations
    ddq_old = ddq;
    ddq = (pinv(M)*(tau - C'- G'-F')')';
        
    % Tustin integration
    dq_old = dq;
    dq = dq + (ddq_old + ddq) * delta_t / 2;
    q = q + (dq + dq_old) * delta_t /2;
    
    % Store result for the final plot
    results_computed_torque(index,:) = q;
    index = index + 1;

end


%% Plot computed torque results for trajectory tracking

figure
for j=1:num_of_joints
    subplot(4,2,j);
    plot(t(1:10001),results_computed_torque(1:10001,j))
%     legend ()
    hold on
%     plot(t(1:10001),results_computed_torque(1:10001,j))
    plot (t,q_des(j,1:length(t)))
    legend ('Computed Torque','Desired angle')
    grid;
end
%%
q_des_error=(results_computed_torque-q_des(:,1:10001)')'
figure
for j=1:num_of_joints
    subplot(4,2,j);
    plot(t,q_des_error(j,1:length(t)))
%     legend ()
%     hold on
%     plot (t,q_des_error_no_friction(j,1:length(t)))
    legend ('Computed torque Error with no friction model')
    grid;
end

%% Trajectory tracking: Backstepping control


% Good Circumference parameters
Kp = 1* diag([1 1 1 1 3 1 1]);

% Good Helix parameters
% Kp = diag([1 1 1 1 3 1 1]);


results_backstepping = q0;
index = 1;
q=q0
dq=q_dot0
ddq=[0 0 0 0 0 0 0]
for i=1:length(t)

   % Error and derivate of the error   
    err = transpose(q_des(:,i)) - q;
    derr = transpose(dq_des(:,i)) - dq;
    
    dqr = transpose(dq_des(:,i)) + err*(Kp);
    ddqr = transpose(ddq_des(:,i)) + derr*(Kp);
    s = derr + err*(Kp');
     
    %Get dynamic matrices
    F = get_FrictionTorque(dq);
    G = get_GravityVector(q);
    C = get_CoriolisMatrix(q,dq);
    M = get_MassMatrix(q);


    % Backstepping Controller
    tau = (M*(ddqr') + C*(dqr') + G + Kp*(s') + err')';      
    
    % Robot joint accelerations
    ddq_old = ddq;
    ddq = (pinv(M)*(tau - transpose(C*(dq'))- G')')';
        
    % Tustin integration
    dq_old = dq;
    dq = dq + (ddq_old + ddq) * delta_t / 2;
    q = q + (dq + dq_old) * delta_t /2;
    
    % Store result for the final plot
    results_backstepping(index,  :) = q;
    index = index + 1;

end

%% Plot computed torque results for backstepping control

figure
for j=1:num_of_joints
    subplot(4,2,j);
    plot(t,results_backstepping(:,j))
    hold on
    plot (t,q_des(j,1:length(t)))
%     hold on
%     plot(t,results_computed_torque(:,j))
    grid;
    legend ('Backstepping Results','Desired angle')
end


%% Selezione del controllo da eseguire
fprintf('Selezionare il tipo di controllo: \n');
fprintf('     #2: adaptive computed torque \n');
fprintf('     #3: LiSlotine \n');
fprintf('     #4 backstepping \n');

sel2 = input(' ... ');


%% Perturbazione iniziale dei parametri
int = 0; % intensit??? percentuale della perturbazione sui parametri
for j = 1:n 
    PANDAsymplified.links(j).m = KUKAmodel.links(j).m .* (1+int/100*0.5); 
end


%% Simulazione
q = zeros(length(t),n); 
q_dot = zeros(length(t),n); 
tau = zeros(length(t),n); 
piArray = zeros(length(t),n*10); % vettore dei parametri dinamici 
q0 = [0 pi/2 -pi/2 0 0] + pi/6*[0.3 0.4 0.2 0.8 0] - pi/12; % partiamo in una posizione diversa da quella di inizio traiettoria
q(1,:) = q0; 
q_dot(1,:) = q_dot0; 

qr_dot = zeros(length(t),n); 
qr_ddot = zeros(length(t),n); 

pi0 = zeros(1,n*10); 
for j = 1:n
    pi0((j-1)*10+1:j*10) = [KUKAmodel.links(j).m KUKAmodel.links(j).m*KUKAmodel.links(j).r ...
        KUKAmodel.links(j).I(1,1) 0 0 KUKAmodel.links(j).I(2,2) 0 KUKAmodel.links(j).I(3,3)];
end
piArray(1,:) = pi0; 

Kp = 1*diag([200 200 200 20 10]);
Kv = 0.1*diag([200 200 200 10 1]); 
Kd = 0.1*diag([200 200 200 20 1]);

% P e R fanno parte della candidata di Lyapunov, quindi devono essere definite positive
R = diag(repmat([1e1 repmat(1e3,1,3) 1e2 1e7 1e7 1e2 1e7 1e2],1,n)); 
P = 0.01*eye(10);
lambda = diag([200, 200, 200, 200, 200])*0.03;



tic
for i = 2:length(t)
    %% Interruzione della simulazione se q diverge
    if any(isnan(q(i-1,:)))
        fprintf('Simulazione interrotta! \n')
        return
    end
    
    
    %% Calcolo dell'errore: e, e_dot
    e = qd(i-1,:) - q(i-1,:); 
    e_dot = qd_dot(i-1,:) - q_dot(i-1,:); 
    s = (e_dot + e*lambda);
    
    qr_dot(i-1,:) = qd_dot(i-1,:) + e*lambda;
    if (i > 2)
        qr_ddot(i-1,:) = (qr_dot(i-1) - qr_dot(i-2)) / timeStep;
    end
    
    
    %% Calcolo della coppia (a partire dal modello)
   
    
    if sel2 == 2||sel2 == 3|| sel2 == 4 
        for j = 1:n 
            KUKAmodel.links(j).m = piArray(i-1,(j-1)*10+1); % elemento 1 di pi
        end
    end
    
    Mtilde = KUKAmodel.inertia(q(i-1,:)); 
    Ctilde = KUKAmodel.coriolis(q(i-1,:),q_dot(i-1,:)); 
    Gtilde = KUKAmodel.gravload(q(i-1,:)); 
    
switch sel2
    case 1
        tau(i,:) = qd_ddot(i-1,:)*Mtilde' + q_dot(i-1,:)*Ctilde' + Gtilde + e_dot*Kv' + e*Kp'; 
    case 2
        tau(i,:) = qd_ddot(i-1,:)*Mtilde' + q_dot(i-1,:)*Ctilde' + Gtilde + e_dot*Kv' + e*Kp';
    case 3
        tau(i,:) = qr_ddot(i-1,:)*Mtilde' + qr_dot(i-1,:)*Ctilde' + Gtilde + s*Kd'; 
    case 4
        tau(i,:) = qr_ddot(i-1,:)*Mtilde' + qr_dot(i-1,:)*Ctilde' + Gtilde + s*Kd' + e*Kp'; 
end
    
    
    %% Dinamica del manipolatore (reale)
    % entrano tau, q e q_dot, devo calcolare M, C e G e ricavare q_ddot
    % integro q_ddot due volte e ricavo q e q_dot
    M = KUKA.inertia(q(i-1,:)); 
    C = KUKA.coriolis(q(i-1,:),q_dot(i-1,:)); 
    G = KUKA.gravload(q(i-1,:)); 
    
    q_ddot = (tau(i,:) - q_dot(i-1,:)*C' - G) * (M')^(-1); 
    
    q_dot(i,:) = q_dot(i-1,:) + timeStep*q_ddot; 
    q(i,:) = q(i-1,:) + timeStep*q_dot(i,:); 
    
    %% Dinamica dei parametri
        q1 = q(i,1); q2 = q(i,2); q3 = q(i,3); q4 = q(i,4); q5 = q(i,5);

        q1_dot = q_dot(i,1); q2_dot = q_dot(i,2); q3_dot = q_dot(i,3); 
        q4_dot = q_dot(i,4); q5_dot = q_dot(i,5);

        qd1_dot = qd_dot(i,1); qd2_dot = qd_dot(i,2); qd3_dot = qd_dot(i,3);
        qd4_dot = qd_dot(i,4); qd5_dot = qd_dot(i,5);

        qd1_ddot = qd_ddot(i,1); qd2_ddot = qd_ddot(i,2); qd3_ddot = qd_ddot(i,3); 
        qd4_ddot = qd_ddot(i,4); qd5_ddot = qd_ddot(i,5);

        g = 9.81;

        regressor2;
    if sel2==2
        piArray_dot = ( R^(-1) * Y' * (Mtilde')^(-1) * [zeros(n) eye(n)] * P * [e e_dot]' )'; 
        
        piArray(i,:) = piArray(i-1,:) + timeStep*piArray_dot; 
    end
    
    if sel2==3
        piArray_dot = (R^(-1) * Y' * s')';  
        
        piArray(i,:) = piArray(i-1,:) + timeStep*piArray_dot; 
    end
    
    %% Progresso Simulazione
    if mod(i,100) == 0
        
        fprintf('Percent complete: %0.1f%%.',100*i/(length(t)-1));
        hms = fix(mod(toc,[0, 3600, 60])./[3600, 60, 1]);
        fprintf(' Elapsed time: %0.0fh %0.0fm %0.0fs. \n', ...
            hms(1),hms(2),hms(3));
    end
    
end

return
