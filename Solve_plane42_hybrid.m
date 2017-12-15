% Find the reflection and transmission for three sections modeled in FE
% Modular code:
% First create a eigsolution file!
% Breno Ebinuma Takiuti
% 12/14/2017

clear 
clc
% close all

%% Load Eig Solution

load  eigSolution_a16b8c16fi100df100ff1000
% load  eigSolution_a16b8c16fi100df1ff1000

%% Material's Constants
% Material: Steel

rho=7800;     %mass per unit valume
E=2.06e11;  %Young's modulus

%% Geometric constants

tb = 5e-3;              % base of the cross-section (tickness) (m)
ha = 7.5e-3;              % height of the cross-section (width) (m)
hb = 2.56e-3;
% hb = 18e-3;
% hb = 36e-3;
hc = 7.5e-3;

La = a.l;
Lb = b.l;               % length of the element (x direction) (m) (3 elem)
Lc = c.l;
L = 0.5;         % Use NeleB to calculate a length of B
NeleB = round(L/b.l);            % Number of elements in B
Sa = tb*(ha);
Sb = tb*hb;
Sc = tb*hc;
Ia = tb*(ha)^3/12;
Ib = tb*(hb)^3/12;
Ic = tb*(hc)^3/12;
beta_ab = Sb/Sa;
beta_bc = Sc/Sb;

nModes = 2;

%% Joint FE model

Kabc = zeros(a.ndof+(a.ndof/2*(NeleB+1)));
Mabc = Kabc;

Kabc(1:a.ndof,1:a.ndof) = Ka;
Mabc(1:a.ndof,1:a.ndof) = Ma;

%% Boundary conditions when using the left eigenvectors

Eb = zeros(a.ndof/2,b.ndof/2);
Ca = zeros(a.ndof/2);

% Describe the boundary (connection a-b)
I = eye(b.ndof/2);
Inoda = (a.ndof/2-b.ndof/2)/2+1:(a.ndof/2-b.ndof/2)/2+b.ndof/2; %SM
%     Inoda = (ar/2-44/2)/2+1:(ar/2-44/2)/2+br/2; %Quasi SM
%     Inoda = 1:br/2;                     %NS
%     Inoda = (ar/2-br/2)+1:ar/2;
% Inoda = (ar-(ra/2)-br/2)/2+1:(ar-(ra/2)-br/2)/2+br/2; %SM2
Inodb = 1:b.ndof/2;

for ii=1:NeleB
    Inodab(:,:,ii) = [round(a.ndof/2*ii)+Inoda, a.ndof+(a.ndof/2*(ii-1))+Inoda];
end
Inodbc = [a.ndof+1+(a.ndof/2*(NeleB-1)):a.ndof+(a.ndof/2*(NeleB+1))];

Ea = eye(a.ndof/2);
Eb(Inoda,Inodb) = I;
Ec = Ea;
Ca(Inoda,Inoda) = I;
Cb = Eb;
Cc = Ca;

md = 1;

for ii=1:NeleB
    Kabc( Inodab(:,:,ii), Inodab(:,:,ii)) = Kabc( Inodab(:,:,ii), Inodab(:,:,ii))+Kb;
    Mabc( Inodab(:,:,ii), Inodab(:,:,ii)) = Mabc( Inodab(:,:,ii), Inodab(:,:,ii))+Mb;
end
Kabc(Inodbc,Inodbc) = Kabc(Inodbc,Inodbc)+Kc;
Mabc(Inodbc,Inodbc) = Mabc(Inodbc,Inodbc)+Mc;

w = 2*pi*f;

for q=1:length(f)
    %% Analytical Solution
    
    AA = eye(2);
    BB = AA;

    kaa(q) = sqrt(w(q))*(rho*Sa/E/Ia)^(1/4);   % Wave number
    kbb(q) = sqrt(w(q))*(rho*Sb/E/Ib)^(1/4);   % Wave number
    kbc(q) = sqrt(w(q))*(rho*Sc/E/Ic)^(1/4); 
    
    lbpaa=exp(-1i*kaa*La);
    lbnaa=exp(1i*kaa*La);
    lbpab=exp(-1i*kbb*Lb);
    lbpac=exp(-1i*kbc*Lc);
    
    
    % Bending
    [RBTaa1(:,:,q),TBTba1(:,:,q)] = WA_reflection_beam_area(beta_ab,kaa(q),kbb(q));
    [RBTbb2(:,:,q),TBTcb2(:,:,q)] = WA_reflection_beam_area(beta_bc,kbb(q),kbc(q));
    
    RBTcc2(:,:,q) = RBTaa1(:,:,q);
    TBTbc2(:,:,q) = TBTba1(:,:,q);
    RBTbb1(:,:,q) = RBTbb2(:,:,q);
    TBTab1(:,:,q) = TBTcb2(:,:,q);
    
    % Bending transition matrix from interface 1 to 2
    TBTb = [exp(-1i*kbb(q)*L) 0; 0 exp(-kbb(q)*L)];
    
    % Bending scattering from 1 to 2
    [RBTAA(:,:,q),TBTCA(:,:,q)] = ThreeSectionRT(RBTaa1(:,:,q),RBTbb2(:,:,q),RBTbb1(:,:,q),TBTba1(:,:,q),TBTcb2(:,:,q),TBTab1(:,:,q),TBTb);
    
    %% Numeric
     
    nmodes_b = length(b.kp(:,q));
    nmodes_a = length(a.kp(:,q));
    kPb = b.kp (1:nmodes_b,q);
    
    PsiQa_p0 = a.PsiQp(:,:,1);
    PsiFa_p0 = a.PsiFp(:,:,1);
    
    CP1ba = [PsiQa_p0*Ca*a.PhiQn(:,:,q) -PsiQa_p0*Cb*b.PhiQp(:,:,q);
        PsiFa_p0*Ea*a.PhiFn(:,:,q) -PsiFa_p0*Eb*b.PhiFp(:,:,q)];
    
    CP2ba = [-PsiQa_p0*Ca*a.PhiQp(:,:,q) PsiQa_p0*Cb*b.PhiQn(:,:,q);
        -PsiFa_p0*Ea*a.PhiFp(:,:,q) PsiFa_p0*Eb*b.PhiFn(:,:,q)]; 
  
    TRTba =(pinv(CP1ba)*CP2ba);
    [TRTr(q), TRTc(q)] = size(TRTba);
    TRT2Pba = TRTba;
    
    mode = round(TRTc(q)/2);
    
    RPaa1(:,:,q) = TRT2Pba(1:nmodes_a,1:nmodes_a);
    TPba1(:,:,q) = TRT2Pba(nmodes_a+1:end,1:nmodes_a);
    RPbb1(:,:,q) = TRT2Pba(nmodes_a+1:end,nmodes_a+1:end);
    TPab1(:,:,q) = TRT2Pba(1:nmodes_a,nmodes_a+1:end);
    
    % Bending transition matrix from interface 1 to 2
%     kPb = b.kp(:,q);
    TPb = diag(exp(-1i*kPb*L));
    
    %% Matrix inversion method as in Harland et al (2000) eq. (54) - b to c

      
    CP1cb = [PsiQa_p0*Cb*b.PhiQn(:,:,q) -PsiQa_p0*Cc*c.PhiQp(:,:,q);
        PsiFa_p0*Eb*b.PhiFn(:,:,q) -PsiFa_p0*Ec*c.PhiFp(:,:,q)];
    
    CP2cb = [-PsiQa_p0*Cb*b.PhiQp(:,:,q) PsiQa_p0*Cc*c.PhiQn(:,:,q);
        -PsiFa_p0*Eb*b.PhiFp(:,:,q) PsiFa_p0*Ec*c.PhiFn(:,:,q)];

    TRTPcb = (pinv(CP1cb)*CP2cb);
    
    RPbb2(:,:,q) = TRTPcb(1:nmodes_b,1:nmodes_b);
    TPcb2(:,:,q) = TRTPcb(nmodes_b+1:end,1:nmodes_b);
    RPcc2(:,:,q) = TRTPcb(nmodes_b+1:end,nmodes_b+1:end);
    TPbc2(:,:,q) = TRTPcb(1:nmodes_b,nmodes_b+1:end);
    
    % Scattering from a to c
    [RPAA(:,:,q),TPCA(:,:,q)] = ThreeSectionRT(RPaa1(:,:,q),RPbb2(:,:,q),RPbb1(:,:,q),TPba1(:,:,q),TPcb2(:,:,q),TPab1(:,:,q),TPb);

    %% Hybrid method by Renno
    
    Z1 = zeros(size(a.PhiQp(:,:,q)));
    Z2 = Z1';
    I = eye(size(a.PhiQp(:,:,q)));
    [rp,cp,~] = size(a.PhiQp);
    [rb,cb,~] = size(Kb);

    PhiQ_p = [a.PhiQp(:,:,q) Z1; Z1 c.PhiQp(:,:,q)];
    PhiQ_n = [a.PhiQn(:,:,q) Z1; Z1 c.PhiQn(:,:,q)];
    PhiF_p = [a.PhiFp(:,:,q) Z1; Z1 c.PhiFp(:,:,q)];
    PhiF_n = [a.PhiFn(:,:,q) Z1; Z1 c.PhiFn(:,:,q)];
    

    PsiQ_n = [a.PsiQn(:,:,q) Z2; Z2 c.PsiQn(:,:,q)];
%     PsiQ_n = [I Z2; Z2 I];

    RA = eye(rp); RB = eye(rp);
    Z3 = zeros(rp);
    
    R = [RA Z3; Z3 RB];
    
    Nind = [9,11,13,15];
    
    R(Nind,Nind) = -eye(length(Nind));


    D1 = (Kabc-w(q)^2*Mabc)*1;
    
   [rabc, cabc] = size(Kabc);
    
    InodE = [1:a.ndof/2,rabc-a.ndof/2+1:rabc];
    InodI = a.ndof/2+1:rabc-a.ndof/2;

%     %Method 1
    DEE = D1(InodE,InodE);
    DEI = D1(InodE,InodI);
    DIE = D1(InodI,InodE);
    DII = D1(InodI,InodI);
    
    Dj = (DEE-DEI*pinv(DII)*DIE);    %Method 1

    %Method 2
%     ni = length(InodE);
%     DTLL = D1(InodE(1:ni/2),InodE(1:ni/2));
%     DTLR = D1(InodE(1:ni/2),InodE(ni/2+1:ni));
%     DTRL = D1(InodE(ni/2+1:ni),InodE(1:ni/2));
%     DTRR = D1(InodE(ni/2+1:ni),InodE(ni/2+1:ni));
%     DTLO = D1(InodE(1:ni/2),InodI);
%     DTRO = D1(InodE(ni/2+1:ni),InodI);
%     DTOL = D1(InodI,InodE(1:ni/2));
%     DTOR = D1(InodI,InodE(ni/2+1:ni));
%     DTOO = D1(InodI,InodI);
%     
%     DLL = DTLL - DTLO*pinv(DTOO)*DTOL;
%     DLR = DTLR - DTLO*pinv(DTOO)*DTOR;
%     DRL = DTRL - DTRO*pinv(DTOO)*DTOL;
%     DRR = DTRR - DTRO*pinv(DTOO)*DTOR;
% %     
%     Dj = [DLL DLR; DRL DRR];    %Method 2

    %Method 3
%     Dj = D0;
        
    Srt(:,:,q) = pinv(PsiQ_n*(-Dj*R*PhiQ_n+R*PhiF_n))*PsiQ_n*(Dj*R*PhiQ_p-R*PhiF_p);
%     Srt(:,:,q) = -pinv(Dj*R*PhiQ_n-R*PhiF_n)*(Dj*R*PhiQ_p-R*PhiF_p);

    RHAA(:,:,q) = Srt(1:cp,1:cp,q);
    THCA(:,:,q) = Srt(cp+1:cp+nModes,1:cp,q);
    
end

TRTP = [RPAA; TPCA];
TRTH = [RHAA; THCA];
TRTA = [RBTAA; TBTCA];
% Cutoff frequencies
Cutoff_ai = [88e3 154e3 166e3 177e3 266e3]; 
Cutoff_bi = [132e3 231e3 249e3 268e3];                           % b12
% Cutoff_bi = 266e3;

Cutoff_a = round(Cutoff_ai/df+1); 
Cutoff_b = round(Cutoff_bi/df);
% Cutoff_a = round(([156e3 166e3 ]-fi)/df); 
% Cutoff_b = round((266e3-fi)/df);


 %% Cutoff plots
% Use the plotCutOffs only for the non zero coefficients, the others plot
% them normally
% 
figure()
plot(f,abs(reshape(RPAA(1,1,:),[1 length(f)])),'b','LineWidth',2);
hold on
% plot(f,abs(reshape(RPAA(2,1,:),[1 length(f)])),'b','LineWidth',2);
% plotCutOffs(f,abs(reshape(RPAA(3,1,:),[1 length(f)])),88, {'r-.','b'},[2,2]);
% plotCutOffs(f,abs(reshape(RPAA(4,1,:),[1 length(f)])),Cutoff_a(2), {'g','b'},[1,2]);
% plotCutOffs(f,abs(reshape(RPAA(5,1,:),[1 length(f)])),Cutoff_a(2:4), {'g','b','r-.','b'},[1,2,2,2]);

plot(f,abs(reshape(RBTAA(1,1,:),[1 length(f)])),'b:')
% plot(f,abs(reshape(RBTAA(2,1,:),[1 length(f)])),'b:')

plot(f,abs(reshape(RHAA(1,1,:),[1 length(f)])),'r--')
% plot(f,abs(reshape(RHAA(1,2,:),[1 length(f)])),'r--')
% plot(f,abs(reshape(RHAA(2,1,:),[1 length(f)])),'r--')

% for ii = 1:length(Cutoff_a)
%     plot([Cutoff_ai(ii) Cutoff_ai(ii)],[-800 800],'k:','LineWidth',0.5)
% end
% for ii = 1:length(Cutoff_b)
%     plot([Cutoff_bi(ii) Cutoff_bi(ii)],[-800 800],'k:','LineWidth',0.5)
% end
% plot([156e3 156e3],[-800 800],'k:','LineWidth',0.5)
% plot([166e3 166e3],[-800 800],'k:','LineWidth',0.5)
% plot([178e3 178e3],[-800 800],'k:','LineWidth',0.5)
% plot([266e3 266e3],[-800 800],'k:','LineWidth',0.5)

%  plot(f,abs(R_WFE3(3,:)),'m-.','LineWidth',3)
%  legend('Analytical Bending','WFE Bending', 'Analytical Longitudinal', 'WFE Longitudinal')
 set(get(gca,'XLabel'),'String','Frequency [Hz]','FontName','Times New Roman','FontSize',12)
 set(get(gca,'YLabel'),'String','|R|','FontName','Times New Roman','FontSize',12)
set(gca,'fontsize',12,'FontName','Times New Roman');
%  axis([fi ff 0 2])

figure()
plot(f,abs(reshape(TPCA(1,1,:),[1 length(f)])),'b','LineWidth',2);
hold on
% plot(f,abs(reshape(TPCA(2,1,:),[1 length(f)])),'b','LineWidth',2);
% plotCutOffs(f,abs(reshape(TPCA(3,1,:),[1 length(f)])),88, {'r-.','b'},[2,2]);
% plotCutOffs(f,abs(reshape(TPCA(4,1,:),[1 length(f)])),Cutoff_a(2), {'g','b'},[1,2]);
% plotCutOffs(f,abs(reshape(TPCA(5,1,:),[1 length(f)])),Cutoff_a(2:4), {'g','b','r-.','b'},[1,2,2,2]);

plot(f,abs(reshape(TBTCA(1,1,:),[1 length(f)])),'b:')
% plot(f,abs(reshape(TBTCA(2,1,:),[1 length(f)])),'b:')

plot(f,abs(reshape(THCA(1,1,:),[1 length(f)])),'r--')
% plot(f,abs(reshape(THCA(1,2,:),[1 length(f)])),'r--')
% plot(f,abs(reshape(THCA(2,1,:),[1 length(f)])),'r--')

% plot([88e3 88e3],[-800 800],'k:','LineWidth',0.5)
% plot([156e3 156e3],[-800 800],'k:','LineWidth',0.5)
% plot([166e3 166e3],[-800 800],'k:','LineWidth',0.5)
% plot([178e3 178e3],[-800 800],'k:','LineWidth',0.5)
% plot([266e3 266e3],[-800 800],'k:','LineWidth',0.5)

%  plot(f,abs(R_WFE3(3,:)),'m-.','LineWidth',3)
%  legend('Analytical Bending','WFE Bending', 'Analytical Longitudinal', 'WFE Longitudinal')
 set(get(gca,'XLabel'),'String','Frequency [Hz]','FontName','Times New Roman','FontSize',12)
 set(get(gca,'YLabel'),'String','|T|','FontName','Times New Roman','FontSize',12)
set(gca,'fontsize',12,'FontName','Times New Roman');
%  axis([fi ff 0 2])
 
%  figure()
% plot(f,abs(reshape(RPAA(1,2,:),[1 length(f)])),'b','LineWidth',2);
% hold on
% plot(f,abs(reshape(RPAA(2,2,:),[1 length(f)])),'b','LineWidth',2);
% % plotCutOffs(f,abs(reshape(RPAA(3,2,:),[1 length(f)])),88, {'r-.','b'},[2,2]);
% % plotCutOffs(f,abs(reshape(RPAA(4,2,:),[1 length(f)])),Cutoff_a(2), {'g','b'},[1,2]);
% % plotCutOffs(f,abs(reshape(RPAA(5,2,:),[1 length(f)])),Cutoff_a(2:4), {'g','b','r-.','b'},[1,2,2,2]);
% 
% plot(f,abs(R_WM(2,:,:)),'b:')
% 
% plot([88e3 88e3],[-800 800],'k:','LineWidth',0.5)
% plot([156e3 156e3],[-800 800],'k:','LineWidth',0.5)
% plot([166e3 166e3],[-800 800],'k:','LineWidth',0.5)
% plot([178e3 178e3],[-800 800],'k:','LineWidth',0.5)
% plot([266e3 266e3],[-800 800],'k:','LineWidth',0.5)
% 
% %  plot(f,abs(R_WFE3(3,:)),'m-.','LineWidth',3)
% %  legend('Analytical Bending','WFE Bending', 'Analytical Longitudinal', 'WFE Longitudinal')
%  set(get(gca,'XLabel'),'String','Frequency [Hz]','FontName','Times New Roman','FontSize',12)
%  set(get(gca,'YLabel'),'String','|R|','FontName','Times New Roman','FontSize',12)
% set(gca,'fontsize',12,'FontName','Times New Roman');
%  axis([fi ff 0 2])
% 
% figure()
% plot(f,abs(reshape(TPCA(1,2,:),[1 length(f)])),'b','LineWidth',2);
% hold on
% plot(f,abs(reshape(TPCA(2,2,:),[1 length(f)])),'b','LineWidth',2);
% plotCutOffs(f,abs(reshape(TPCA(3,2,:),[1 length(f)])),88, {'r-.','b'},[2,2]);
% plotCutOffs(f,abs(reshape(TPCA(4,2,:),[1 length(f)])),Cutoff_a(2), {'g','b'},[1,2]);
% plotCutOffs(f,abs(reshape(TPCA(5,2,:),[1 length(f)])),Cutoff_a(2:4), {'g','b','r-.','b'},[1,2,2,2]);
% 
% plot(f,abs(T_WM(2,:)),'b:')
% 
% plot([88e3 88e3],[-800 800],'k:','LineWidth',0.5)
% plot([156e3 156e3],[-800 800],'k:','LineWidth',0.5)
% plot([166e3 166e3],[-800 800],'k:','LineWidth',0.5)
% plot([178e3 178e3],[-800 800],'k:','LineWidth',0.5)
% plot([266e3 266e3],[-800 800],'k:','LineWidth',0.5)
% 
% %  plot(f,abs(R_WFE3(3,:)),'m-.','LineWidth',3)
% %  legend('Analytical Bending','WFE Bending', 'Analytical Longitudinal', 'WFE Longitudinal')
%  set(get(gca,'XLabel'),'String','Frequency [Hz]','FontName','Times New Roman','FontSize',12)
%  set(get(gca,'YLabel'),'String','|T|','FontName','Times New Roman','FontSize',12)
% set(gca,'fontsize',12,'FontName','Times New Roman');
%  axis([fi ff 0 2])
%  
 
%% Energy plots
% 
%  % Bending Incident TA Kinetic Energy
%  figure()
%  plot(f,abs(EIbbkin_avLy./EIbbkin_avL)*100,'b*','LineWidth',1)
%  hold on
%  plot(f,abs(EIbbkin_avLx./EIbbkin_avL)*100,'rp','LineWidth',1)
%  plot(f,abs(EIbbkin_avLya./EIbbkin_avLa)*100,'k*','LineWidth',1)
%  plot(f,abs(EIbbkin_avLxa./EIbbkin_avLa)*100,'kp','LineWidth',1)
% 
%  legend('kEy_{inc}/kE_{inc}','kEx_{inc}/kE_{inc}')
% % %  title('Symmetric discontinuity')
%  set(get(gca,'XLabel'),'String','Frequency [Hz]','FontName','Times New Roman','FontSize',12)
%  set(get(gca,'YLabel'),'String','Time-averaged kinetic energy [%]','FontName','Times New Roman','FontSize',12)
%  set(gca,'fontsize',12,'FontName','Times New Roman');
%  axis([fi f(q) -1 101])
% 
% 
% for ii = 1:length(Cutoff_a)
%     plot([Cutoff_ai(ii) Cutoff_ai(ii)],[-800 800],'k:','LineWidth',0.5)
% end
% for ii = 1:length(Cutoff_b)
%     plot([Cutoff_bi(ii) Cutoff_bi(ii)],[-800 800],'k:','LineWidth',0.5)
% end
% 
%  figure()
%  plot(f,(ERbbkin_avLy./ERbbkin_avL)*100,'b*','LineWidth',1)
%  hold on
%  plot(f,(ERbbkin_avLx./ERbbkin_avL)*100,'rp','LineWidth',1)
%  plot(f,(ETbbkin_avLy./ETbbkin_avL)*100,'go','LineWidth',1)
%  plot(f,(ETbbkin_avLx./ETbbkin_avL)*100,'ms','LineWidth',1)
% 
%  legend('kEy_{refl}/kE_{refl}','kEx_{refl}/kE_{refl}','kEy_{trans}/kE_{trans}','kEx_{trans}/kE_{trans}')
% % %  title('Symmetric discontinuity')
%  set(get(gca,'XLabel'),'String','Frequency [Hz]','FontName','Times New Roman','FontSize',12)
%  set(get(gca,'YLabel'),'String','Time-averaged kinetic energy [%]','FontName','Times New Roman','FontSize',12)
%  set(gca,'fontsize',12,'FontName','Times New Roman');
%  axis([fi f(q) -1 101])
% for ii = 1:length(Cutoff_a)
%     plot([Cutoff_ai(ii) Cutoff_ai(ii)],[-800 800],'k:','LineWidth',0.5)
% end
% for ii = 1:length(Cutoff_b)
%     plot([Cutoff_bi(ii) Cutoff_bi(ii)],[-800 800],'k:','LineWidth',0.5)
% end
% 

%% Save RT files

filename = ['RT_' num2str(ndofa) 'b' num2str(ndofb) 'c' num2str(ndofc) ...
    'fi' num2str(fi) 'df' num2str(df) 'ff' num2str(ff)];
save(filename, 'TRTP', 'TRTH','TRTA');