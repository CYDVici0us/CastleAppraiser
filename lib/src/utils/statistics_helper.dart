
import 'dart:math';

import 'package:flutter/material.dart';

class StatHelper {

  static double getMax(List<double> l){
    if (l.isEmpty) return 0;
    double retVal = l.first;
    for(var i=0;i<l.length;i++){
     if(l[i]>retVal)retVal = l[i];
    }
    return retVal;
  }

  static double getMin(List<double> l){
    if (l.isEmpty) return 0;
    double retVal = l.first;
    for(var i=0;i<l.length;i++){
      if(l[i]<retVal)retVal = l[i];
    }
    return retVal;
  }

  static double getAverage(List<double> l){
    if (l.isEmpty) return 0;
    double retVal = 0;
    for(var i=0;i<l.length;i++){
      retVal += l[i];
    }
    return retVal/l.length;
  }

  static double getMedian(List<double> l){
    if (l.isEmpty) return 0;
    final sorted = List<double>.from(l)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2.0;
  }

  /// Mean of values within 2σ of the overall mean. Falls back to the plain
  /// average when the filtered set would be empty (e.g. all values identical).
  static double getAverageRemoveOutlier(List<double> l){
    if (l.isEmpty) return 0;
    if (l.length == 1) return l.first;

    double retVal = 0;
    double averageTotal = getAverage(l);
    double std = getSTD(l);
    int inclusiveCount = 0;
    for(var i=0;i<l.length;i++){
      if(l[i] >= averageTotal - (std*2) && l[i] <= averageTotal + (std*2)){
        retVal += l[i];
        inclusiveCount++;
      }
    }
    if (inclusiveCount == 0) return averageTotal;
    return retVal/inclusiveCount;
  }

  static double getSTD(List<double> l){
    if (l.isEmpty) return 0;
    double retVal = 0;
    double n = l.length.toDouble();
    double avg = getAverage(l);
    double diffsum = 0;
    for(var i=0;i<l.length;i++){
      diffsum += ((l[i]-avg)*(l[i]-avg));
    }
    retVal = sqrt(diffsum/n);

    return retVal;
  }

  static Color getColorBasedOnScore(int score) {
    // use withAlpha()
    if (score > 50) return Colors.green;
    if (score > 40) return Colors.lightGreen;
    if (score > 30) return Colors.orange;
    if (score > 20) return Colors.orangeAccent;

    return Colors.redAccent;
  }

}
