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

string GenerateStar(string var, int degree) {
    string result = "";
    for(int i = 0;i < degree - 1;i++) {
        result += var;
        result += "*";
    }
    result += var;
    return result;
}

void GeneratePolyVars(int degree, const vector<string> &variables, vector<vector<vector<string>>> &polyVars) {
    vector<vector<string>> res;
    for(unsigned i = 0;i < variables.size();i++) {
        vector<string> varTemp;
        varTemp.push_back(GenerateStar(variables[i], degree));
        for(int j = degree - 1;j >= 1;j--) {
            string prefix = "";
            prefix += GenerateStar(variables[i], j);
            int remain = degree - j;
            for(unsigned m = i + 1;m < variables.size();m++) {
                for(unsigned n = 0;n < polyVars[remain - 1][m].size();n++) {
                    string temp = prefix;
                    temp += "*";
                    temp += polyVars[remain - 1][m][n];
                    varTemp.push_back(temp);
                }
            }
        }
        res.push_back(varTemp);
    }
    polyVars.push_back(res);
}

int main(int argc, char** argv) {
    if(argc < 3) {
        cerr << "GeneratePolynomial.cpp needs more paramters" << endl;
        cerr << "./outputHyperplane test_file degree" << endl;
        exit(-1);
    }
    ifstream testFile;
    testFile.open(argv[1], ios::out | ios::in);
    if(!testFile) {
        cerr << "Can't open " << argv[1] << endl;
        exit(-1);
    }

    string line;
    vector<string> variables;
    int degree;
    degree = stoi(argv[2]);
    while(getline(testFile, line)) {
        vector<string> res = Split(line, "@");
        if(res[0] == "names") {
            variables = Split(res[1], " ");
        }
    }

    vector<vector<vector<string>>> polyVars;
    vector<vector<string>> initial;
    for(int i = 0;i < variables.size();i++) {
        vector<string> temp;
        temp.push_back(variables[i]);
        initial.push_back(temp);
    }
    polyVars.push_back(initial);
    for(int i = 2;i <= degree;i++) {
        GeneratePolyVars(i, variables, polyVars);
    }

    for(unsigned i = 0;i < polyVars.size();i++) {
        for(unsigned j = 0;j < polyVars[i].size();j++) {
            for(unsigned k = 0;k < polyVars[i][j].size();k++)
                cout << polyVars[i][j][k] << " ";
        }
    }
    cout << endl;

    return 0;
}
