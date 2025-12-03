%Proyecto - Industria 4.0
% Camilo Escobar Naranjo - Cargos García Ávila

%% 1. Leer el archivo
T = readtable('TEMPERATURA FASES DEL TRANSFORMADOR EXITACION.xlsx','Sheet', 'DefaultView');

% T tiene columnas: FECHA, GENERADOR, MAGNITUD, VALOR

%% 2. Convertir VALOR (que viene con coma) a número
T.VALOR = strrep(string(T.VALOR), ',', '.');   % cambiar coma por punto
T.VALOR_num = str2double(T.VALOR);            % convertir a double

%% 3. Filtrar las tres fases del transformador de excitación
esFase = contains(T.MAGNITUD, 'Trans. Excitacion Fase');
Tfase = T(esFase, :);

%% 4. Pasar de formato largo a ancho (una columna por fase)
TfaseWide = unstack(Tfase, 'VALOR_num', 'MAGNITUD', ...
                    'GroupingVariables', 'FECHA');
TfaseWide.Properties.VariableNames = { ...
    'FECHA', 'T_FaseA', 'T_FaseB', 'T_FaseC'};

%% 5. Crear variables de tiempo
TfaseWide.DayOfYear = day(TfaseWide.FECHA, 'dayofyear');
TfaseWide.Month     = month(TfaseWide.FECHA);
TfaseWide.Hour      = hour(TfaseWide.FECHA);
TfaseWide.Weekday   = weekday(TfaseWide.FECHA); % 1=domingo, 7=sábado

%% 6. Matriz de entrada X y salidas yA, yB, yC
X  = [TfaseWide.DayOfYear, TfaseWide.Month, ...
      TfaseWide.Hour, TfaseWide.Weekday];

yA = TfaseWide.T_FaseA;
yB = TfaseWide.T_FaseB;
yC = TfaseWide.T_FaseC;

idxNoApagado = (yA > 0) & (yB > 0) & (yC > 0);
X  = X(idxNoApagado, :);
yA = yA(idxNoApagado);
yB = yB(idxNoApagado);
yC = yC(idxNoApagado);

%% 7. Partición entrenamiento/prueba
n = size(X,1);
cv = cvpartition(n, 'Holdout', 0.2);

idxTrain = training(cv);
idxTest  = test(cv);

Xtrain = X(idxTrain, :);
Xtest  = X(idxTest,  :);

yAtrain = yA(idxTrain);  yAtest = yA(idxTest);
yBtrain = yB(idxTrain);  yBtest = yB(idxTest);
yCtrain = yC(idxTrain);  yCtest = yC(idxTest);

%% 8. Modelo para Fase A
MdlA = fitrensemble(Xtrain, yAtrain, ...
    'Method', 'Bag', ...               % Bagging de árboles
    'NumLearningCycles', 100, ...
    'Learners', 'tree');

%% 9. Modelo para Fase B
MdlB = fitrensemble(Xtrain, yBtrain, ...
    'Method', 'Bag', ...
    'NumLearningCycles', 100, ...
    'Learners', 'tree');

%% 10. Modelo para Fase C
MdlC = fitrensemble(Xtrain, yCtrain, ...
    'Method', 'Bag', ...
    'NumLearningCycles', 100, ...
    'Learners', 'tree');

%% 11. Predicciones en el conjunto de prueba
yA_pred = predict(MdlA, Xtest);
yB_pred = predict(MdlB, Xtest);
yC_pred = predict(MdlC, Xtest);

%% 12. Función auxiliar para métricas
rmse = @(y,yp) sqrt(mean((y - yp).^2));
R2   = @(y,yp) 1 - sum((y-yp).^2) / sum((y-mean(y)).^2);

% Fase A
rmseA = rmse(yAtest, yA_pred);
R2A   = R2(yAtest, yA_pred);

% Fase B
rmseB = rmse(yBtest, yB_pred);
R2B   = R2(yBtest, yB_pred);

% Fase C
rmseC = rmse(yCtest, yC_pred);
R2C   = R2(yCtest, yC_pred);

%Visualizar Predicciones
%A
figure;
plot(yAtest, 'o-','LineWidth', 1.3); hold on;
plot(yA_pred, 'x-','LineWidth', 1.3);
legend('Real','Predicho');
xlabel('Muestras de prueba');
ylabel('Temperatura Fase A [°C]');
title('Comparación temperatura real vs predicha - Fase A');
grid on;

%B
figure;
plot(yBtest, 'o-', 'LineWidth', 1.3); hold on;
plot(yB_pred, 'x-', 'LineWidth', 1.3);
legend('Real','Predicho');
xlabel('Muestras de prueba');
ylabel('Temperatura Fase B [°C]');
title('Comparación temperatura real vs predicha - Fase B');
grid on;

%C
figure;
plot(yCtest, 'o-', 'LineWidth', 1.3); hold on;
plot(yC_pred, 'x-', 'LineWidth', 1.3);
legend('Real','Predicho');
xlabel('Muestras de prueba');
ylabel('Temperatura Fase C [°C]');
title('Comparación temperatura real vs predicha - Fase C');
grid on;

%% 13 Modelo para predecir

nuevoX = [200 7 11 3];  % [DayOfYear Month Hour Weekday]

T_FaseA_pred = predict(MdlA, nuevoX);
T_FaseB_pred = predict(MdlB, nuevoX);
T_FaseC_pred = predict(MdlC, nuevoX);

fprintf('Predicción Fase A: %.2f °C\n', T_FaseA_pred);
fprintf('Predicción Fase B: %.2f °C\n', T_FaseB_pred);
fprintf('Predicción Fase C: %.2f °C\n', T_FaseC_pred);

fechaNueva = datetime(2025,11,30,9,0,0); % 30 nov 2025, 09:00
doy  = day(fechaNueva, 'dayofyear');
mon  = month(fechaNueva);
hr   = hour(fechaNueva);
wday = weekday(fechaNueva);

nuevoX = [doy, mon, hr, wday];

%% Error por muestra

eA = yAtest - yA_pred;
eB = yBtest - yB_pred;
eC = yCtest - yC_pred;

figure;

subplot(3,1,1)
stem(eA, 'filled'); grid on;
title('Error por muestra - Fase A');
ylabel('Error [°C]');

subplot(3,1,2)
stem(eB, 'filled'); grid on;
title('Error por muestra - Fase B');
ylabel('Error [°C]');

subplot(3,1,3)
stem(eC, 'filled'); grid on;
title('Error por muestra - Fase C');
xlabel('Muestras');
ylabel('Error [°C]');
