#include<algorithm>
#include<fstream>
#include<iostream>
#include<iterator>
#include<regex>
#include<string>
#include<vector>
using namespace std;

vector<string> Split(const string& in, const string& delim) {
    regex re{ delim };
    return vector<string> {
        sregex_token_iterator(in.begin(), in.end(), re, -1),
            sregex_token_iterator()
    };
}

int main(int argc, char** argv) {
    if(argc < 3) {
        cerr << "OutputHyperplane.cpp needs more paramters" << endl;
        cerr << "./outputHyperplane model_file data_file" << endl;
        exit(-1);
    }
    ifstream modelFile;
    ifstream dataFile;
    modelFile.open(argv[1], ios::out | ios::in);
    dataFile.open(argv[2], ios::out | ios::in);
    if(!modelFile) {
        cerr << "Can't open " << argv[1] << endl;
        exit(-1);
    }
    if(!dataFile) {
        cerr << "Can't open " << argv[2] << endl;
        exit(-1);
    }

    // get the first line of dataFile
    string line;
    getline(dataFile, line);
    vector<string> res = Split(line, " ");
    int flag = stoi(res[0]);
    vector<int> data;
    for(int i = 1;i < res.size();i++){
        vector<string> temp = Split(res[i], ":");
        data.push_back(stoi(temp[1]));
    }

    // get the model of invariant
    getline(modelFile, line);
    double b = stod(line);
    vector<double> w;

    while(getline(modelFile, line)) {
        w.push_back(stod(line));
    }
    if(data.size() != w.size()) {
        cerr << "There are something error in datafile or modelfile"
            << endl;
        exit(-1);
    }

    // Calculating the final result
    double result = 0;
    for(int i = 0;i < data.size();i++) {
        result += w[i] * data[i];
    }
    result += b;
    if((result >= 0 && flag >= 0) || (result <= 0 && flag <= 0)) return 1;
    return -1;
}
