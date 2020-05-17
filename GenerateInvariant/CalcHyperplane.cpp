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

string doubleContain2(const double &dbNum)
{
    char *chCode;
    chCode = new(std::nothrow)char[100];
    sprintf(chCode, "%.2lf", dbNum);
    string strCode(chCode);
    delete []chCode;
    return strCode;
}

int main(int argc, char** argv){
    if(argc < 3) {
        cerr << "CalcHyperplane.cpp needs more paramters" << endl;
        cerr << "./CalcHyperplane input.model config_file" << endl;
        exit(-1);
    }

    ifstream svFile;
    ifstream configFile;
    svFile.open(argv[1], ios::out | ios::in );
    configFile.open(argv[2], ios::out | ios::in );
    if(!svFile) {
        cerr << "Can't open " << argv[1] << endl;
        exit(-1);
    }
    if(!configFile) {
        cerr << "Can't open " << argv[2] << endl;
        exit(-1);
    }

    string line;
    // if read SV, support vector is after "SV"
    bool isSV = false;
    // the first parameter of support vector
    // is coefficient
    vector<double> coefficient;
    // the remain part of support vector is alpha
    vector<vector<double>> alpha;

    bool isContainDouble = false;
    while(getline(configFile, line)) {
        vector<string> res = Split(line, "@");
        if(res[0] == "types") {
            vector<string> temp = Split(res[1], " ");
            for(int i = 0;i < temp.size();i++) {
                if(temp[i] == "double") isContainDouble = true;
            }
        }
    }

    while(getline(svFile, line)){
        vector<string> res = Split(line, " ");
        if(res[0] == "rho") {
            double temp = -stod(res[1]);
            if(isContainDouble)
                cout << temp << endl;
            else
                cout << doubleContain2(temp) << endl;
        }
        else if(res[0] == "SV") {
            isSV = true;
            continue;
        }
        if(isSV){
            coefficient.push_back(stod(res[0]));
            vector<double> temp;
            for(int i = 1;i < res.size();i++){
                vector<string> alphaItem = Split(res[i], ":");
                temp.push_back(stod(alphaItem[1]));
            }
            alpha.push_back(temp);
        }
    }

    if(alpha.size() != coefficient.size()) {
        cerr << "coefficient size is not equal to alpha size" << endl;
        exit(-1);
    }
    unsigned size = alpha[0].size();
    for(unsigned i = 0;i < size;i++){
        double result = 0;
        for(int j = 0;j < coefficient.size();j++){
            result += coefficient[j] * alpha[j][i];
        }
        if(isContainDouble)
            cout << result << endl;
        else
            cout << doubleContain2(result) << endl;
    }

    svFile.close();
    return 0;
}
