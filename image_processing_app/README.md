# image_processing_app
📌 Projeto 1: Processamento Paralelo de Imagens

📖 Descrição

Este projeto implementa um sistema de processamento de imagens utilizando programação paralela para otimizar o desempenho. A aplicação permite carregar imagens e aplicar filtros em tempo real, incluindo:

Conversão para escala de cinza

Separação de canais de cor (RGB)

Aplicação de kernels de convolução (ex: detecção de bordas)

A paralelização é realizada utilizando Isolates e Compute do Dart para distribuir o processamento em múltiplos núcleos.

🚀 Funcionalidades

Carregamento de imagens

Aplicação de filtros de imagem

Processamento paralelo para otimização

Interface intuitiva para interação do usuário

📂 Estrutura do Projeto

ImageProcessingApp/
│── lib/
│   │── screens/   # Interface do usuário
│   │── managers/  # Controle do processamento
│   │── utils/     # Algoritmos de processamento
│── assets/
│── android/
│── ios/
│── main.dart      # Arquivo principal
│── pubspec.yaml   # Dependências do Flutter
│── README.md

🛠 Tecnologias Utilizadas

Flutter (Dart)

image package para manipulação de imagens

Compute e Isolates para paralelização

🔧 Como Executar

Instale as dependências do Flutter:

flutter pub get

Execute o projeto em um emulador ou dispositivo: