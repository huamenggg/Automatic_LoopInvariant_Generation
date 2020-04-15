#include<algorithm>
#include<cmath>
#include<ctime>
#include<fstream>
#include<iostream>
#include<iterator>
#include<random>
#include<regex>
#include<string>
#define DEBUG
using namespace std;

void GenerateSample(const vector<double> &w, double b, ofstream &outputFile) {
    int size = w.size();
    vector<int> result;
    for(int i = 0;i < size - 1;i++) {
        int temp = (rand() % 201) - 100;
        result.push_back(temp);
    }

    double sum = 0;
    for(int i = 0;i < size - 1;i++){
        sum += w[i] * result[i];
    }
    double x_n = (-b - sum) / w[size - 1];
    int x_n_int = (int)x_n;
    if(x_n - x_n_int < 0.5) {
        result.push_back(x_n_int);
    }
    else {
        result.push_back(x_n_int + 1);
    }

    for(int i = 0;i < size;i++){
       outputFile << result[i] << " "; 
    }
    outputFile << endl;
}

int main(int argc, char** argv){
    if(argc < 3) {
        cerr << "PredictNode.cpp needs more paramters" << endl;
        cerr << "./PredictNode input.model.parameter outputname" << endl;
        exit(-1);
    }

    ifstream paramFile;
    ofstream outputFile;
    paramFile.open(argv[1], ios::out | ios::in );
    outputFile.open(argv[2], ios::out);
    if(!paramFile) {
        cerr << "Can't open " << argv[1] << endl;
        exit(-1);
    }
    if(!outputFile) {
        cerr << "Can't open " << argv[2] << endl;
        exit(-1);
    }

    string line;

    getline(paramFile, line);
    // w^T x + b = 0
    double b = stod(line);

    srand((int)time(0));

    vector<double> w;
    while(getline(paramFile, line)){
        w.push_back(stod(line));
    }

    if(w.size() == 1) GenerateSample(w, b, outputFile);
    else {
    for(int i = 0;i < 5;i++)
        GenerateSample(w, b, outputFile);
    }

    paramFile.close();
    outputFile.close();
    return 0;
}
