<div align="center">
  <img src="https://codecarbon.gallerycdn.vsassets.io/extensions/codecarbon/codecarbon/0.2.0/1730577027930/Microsoft.VisualStudio.Services.Icons.Default" width="150" alt="CodeCarbon Logo">

  # CodeCarbon: Guia para o Projeto TI Verde
</div>

###  O que é o CodeCarbon?
Uma biblioteca Python que mede o consumo de energia de um computador enquanto um programa roda e calcula as emissões de CO2 equivalentes. Ele faz isso rastreando o uso da CPU, RAM e GPU e usando dados da matriz energética da região que for determinada.


### Como instalar?

```bash
pip install codecarbon
```

### Como utilizar o CodeCarbon?
Abaixo são apresentadas quatro maneiras de utilizar o CodeCarbon:


1. Como objeto explícito

    O tracker é instanciado e controlado com os métodos `start()` e `stop()` explicitamente.

    ```python
    from codecarbon import EmissionsTracker

    tracker = EmissionsTracker()
    tracker.start() # início da medição

    try:
        
        # código que se quer medir
        # código que se quer medir
        # código que se quer medir

    finally:
        tracker.stop() # término da medição
    ```

    O uso do bloco `try/finally` garante que a medição seja salva mesmo em caso de erro durante a execução.


2. Como context manager

    Utiliza a estrutura `with` do Python. O rastreamento das emissões é iniciado automaticamente ao entrar no bloco e encerrado ao sair.

    ```python
    from codecarbon import EmissionsTracker

    with EmissionsTracker() as tracker:

        # código que se quer medir
        # código que se quer medir
        # código que se quer medir
    ```


3. Como decorator

    Ideal para medir o consumo de uma função específica.

    ```python

    from codecarbon import track_emissions

    @track_emissions
    def funcao():

        # código que se quer medir
        # código que se quer medir
        # código que se quer medir
    ```


4. Como wrapper externo

    O CodeCarbon roda por fora da aplicação medindo o consumo da máquina.

    ```python
    from codecarbon import EmissionsTracker
    import subprocess

    tracker = EmissionsTracker()
    tracker.start()

    processo = subprocess.Popen(["um_comando"])
    processo.wait()

    emissions = tracker.stop()
    ```
    
    Método utilizado no app __schoolmanagement__, sendo sua principal vantagem não alterar nada do código original.


### Qual a saída do CodeCarbon?
Após a execução, é gerado um arquivo `.csv` com diversas informações. Abaixo estão destacadas as mais relevantes:


|Coluna|Descrição|
|---|---|
|duration|Duração da execução em segundos|
|emissions|Emissões totais de CO2 em kg|
|cpu_energy|Energia gasta pela CPU em kWh|
|ram_energy|Energia gasta pela RAM em kWh|
|energy_consumed|Energia total gasta em kWh|
|country_name|País onde a medição foi feita|

### Qual a diferença entre o modo offline e online?
A versão offline é utilizada em ambientes sem acesso à internet, mas as formas de utilizar o CodeCarbon permanecem inalteradas com exceção que se faz necessário o uso do parâmetro `country_iso_code` que representa o código ISO do país onde a infraestrutura está hospedada.

> **Observação importante:** durante os testes, o CodeCarbon conseguiu acessar os valores reais do consumo de energia nativamente no Linux. No Windows, sem configuração adicional, a biblioteca funcionou através de estimativas. Portanto, recomendamos trabalhar com ele no Linux para maior precisão.