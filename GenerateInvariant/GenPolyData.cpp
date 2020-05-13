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

double GenerateStar(double var, int degree) {
    double result = 1;
    for(int i = 0;i < degree;i++) {
        result *= var;
    }
    return result;
}

void GeneratePolyVars(int degree, const vector<double> &variables, vector<vector<vector<double>>> &polyVars) {
    vector<vector<double>> res;
    for(unsigned i = 0;i < variables.size();i++) {
        vector<double> varTemp;
        varTemp.push_back(GenerateStar(variables[i], degree));
        for(int j = degree - 1;j >= 1;j--) {
            double prefix = GenerateStar(variables[i], j);
            int remain = degree - j;
            for(unsigned m = i + 1;m < variables.size();m++) {
                for(unsigned n = 0;n < polyVars[remain - 1][m].size();n++) {
                    double temp = prefix;
                    temp *= polyVars[remain - 1][m][n];
                    varTemp.push_back(temp);
                }
            }
        }
        res.push_back(varTemp);
    }
    polyVars.push_back(res);
}
void OutputPolyData(vector<double> &data, int degree) {
    vector<vector<vector<double>>> polyVars;
    vector<vector<double>> initial;
    for(unsigned i = 0;i < data.size();i++) {
        vector<double> temp;
        temp.push_back(data[i]);
        initial.push_back(temp);
    }
    polyVars.push_back(initial);
    for(int i = 2;i <= degree;i++) {
        GeneratePolyVars(i, data, polyVars);
    }

    int index = 1;
    for(unsigned i = 0;i < polyVars.size();i++) {
        for(unsigned j = 0;j < polyVars[i].size();j++) {
            for(unsigned k = 0;k < polyVars[i][j].size();k++) {
                cout << index << ":" << polyVars[i][j][k] << " ";
                index++;
            }
        }
    }
}

int main(int argc, char** argv) {
    if(argc < 3) {
        cerr << "GeneratePolynomial.cpp needs more paramters" << endl;
        cerr << "./outputHyperplane data_file degree" << endl;
        exit(-1);
    }
    ifstream dataFile;
    dataFile.open(argv[1], ios::out | ios::in);
    if(!dataFile) {
        cerr << "Can't open " << argv[1] << endl;
        exit(-1);
    }
    int degree = stoi(argv[2]);

    string line;
    vector<double> data;
    while(getline(dataFile, line)) {
        vector<string> res = Split(line, " ");
        for(int i = 1;i < res.size();i++) {
            vector<string> temp = Split(res[i], ":");
            data.push_back(stod(temp[1]));
        }
        cout << res[0] << " ";
        OutputPolyData(data, degree);
        cout << endl;
        data.clear();
    }

    return 0;
}
