## Purpose

This is a library project to collect or create examples of Kubernetes provisioning.

Provisioning a Kubernetes cluster is not easy for beginners, and testing or POCing Kubernetes features is even harder.

So I created this project because I thought that sharing own know-how or automated scripts, even if they're not as well organized as possible, could give your work some momentum.

If you have any simple automated script for provisioning kubernetes clusters, please share yours!!

## 목적

이 레파지토리는 쿠버네티스 프로비저닝의 예제를 수집하거나 생성하기 위한 라이브러리 프로젝트입니다.

초보자가 Kubernetes 클러스터를 프로비저닝하는 것은 쉽지 않으며, Kubernetes 기능을 테스트하거나 PoC하는 것은 더더욱 어렵습니다.

그래서 잘 정리되어 있지는 않더라도 자신만의 노하우나 자동화된 스크립트를 공유하면 작업에 탄력을 받을 수 있다고 생각해서 이 프로젝트 시작하게 되었습니다.

쿠버네티스 클러스터 프로비저닝을 위한 간단한 자동화 스크립트가 있다면 공유해 주세요!!!

## Structures

```
.
├── aws
│   ├── ec2
│   │   ├── 00-simple-public-cluster
│   │   ├── 01-simple-public-cluster-with-spot-instance
│   │   └── 02-single-public-private-cluster-with-bastion
│   └── eks
│       └── closed-network-eks
└── vagrant
    └── 00-ubuntu2004-rke2

```
