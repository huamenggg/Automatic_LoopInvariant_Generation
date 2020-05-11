#include<algorithm>
#include<cmath>
#include<ctime>
#include<fstream>
#include<iostream>
#include<iterator>
#include<random>
#include<regex>
#include<string>
#include<sys/timeb.h>
#include<vector>
#include<z3++.h>
using namespace std;

void GenerateSample(const vector<double> &w, double b,
        default_random_engine &e, uniform_int_distribution<int> &uInt,
        uniform_real_distribution<double> uDouble) {
    int size = w.size();
    vector<int> result;
    for(int i = 0;i < size - 1;i++) {
        int temp = uInt(e);
        result.push_back(temp);
    }

    double sum = 0;
    for(int i = 0;i < size - 1;i++){
        sum += w[i] * result[i];
    }
    double x_n = (-b - sum) / w[size - 1];
    int x_n_int = floor(x_n);
    if(x_n - x_n_int < 0.5) {
        result.push_back(x_n_int);
    }
    else {
        result.push_back(x_n_int + 1);
    }

    for(int i = 0;i < size;i++){
       cout << result[i] << " ";
    }
    cout << endl;
}

int main(int argc, char** argv){
    if(argc < 2) {
        cerr << "PredictNode.cpp needs more paramters" << endl;
        cerr << "./PredictNode input.model.parameter" << endl;
        exit(-1);
    }

    ifstream paramFile;
    paramFile.open(argv[1], ios::out | ios::in );
    if(!paramFile) {
        cerr << "Can't open " << argv[1] << endl;
        exit(-1);
    }

    string line;

    getline(paramFile, line);
    // w^T x + b = 0
    double b = stod(line);

    vector<double> w;
    while(getline(paramFile, line)){
        w.push_back(stod(line));
    }

    struct timeb timeSeed;
    ftime(&timeSeed);

    unsigned mileTime = timeSeed.time * 1000 + timeSeed.millitm;
    default_random_engine e(mileTime);
    uniform_int_distribution<int> uInt(-100, 100);
    uniform_real_distribution<double> uDouble(-100, 100);

    if(w.size() == 1) GenerateSample(w, b, e, uInt, uDouble);
    else {
    for(int i = 0;i < 5;i++)
        GenerateSample(w, b, e, uInt, uDouble);
    }

    paramFile.close();
    return 0;
}
