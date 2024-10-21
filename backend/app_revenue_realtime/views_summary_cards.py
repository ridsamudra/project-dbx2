# app_revenue_realtime/views_summary_cards.py

import json
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import JSONParser
from django.db.models import Sum, Max
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal
from .models import RevenueRealtime
from .serializers import SummaryCardsSerializer
from app_users.utils import get_session_data_from_body, fetch_user_locations, is_admin_user
from app_income_parkir.models import IncomeParkir
from app_income_member.models import IncomeMember
from app_income_manual.models import IncomeManual

@method_decorator(csrf_exempt, name='dispatch')
class SummaryCardsView(APIView):
    """
    API View for generating summary cards containing revenue and transaction statistics.
    Handles both real-time and historical data aggregation.
    
    Dynamic Behavior:
    - All calculations use the latest timestamp (latest_waktu) as reference
    - When new transactions occur:
        1. Today's numbers (pendapatan_hari_ini, transaksi_hari_ini) update automatically
        2. Total numbers (total_pendapatan, total_transaksi) also update as they include today's numbers
    """
    parser_classes = [JSONParser]
    
    def get(self, request, *args, **kwargs):
        try:
            # Step 1: Session Data Validation
            session_data_result = get_session_data_from_body(request)
            if isinstance(session_data_result, dict) and 'error' in session_data_result:
                session_data_str = request.GET.get('session_data') or request.headers.get('X-Session-Data')
                if session_data_str:
                    try:
                        session_data = json.loads(session_data_str)
                    except json.JSONDecodeError:
                        return Response({"status": "error", "message": "Invalid session data format"}, status=400)
                else:
                    return Response({"status": "error", "message": session_data_result['error']}, status=400)
            else:
                session_data = session_data_result

            # Step 2: User Authorization Check
            is_admin = is_admin_user(session_data)
            if isinstance(is_admin, dict) and 'error' in is_admin:
                return Response({"status": "error", "message": is_admin['error']}, status=400)

            # Step 3: Location Access Validation
            locations = fetch_user_locations(session_data)
            if isinstance(locations, dict) and 'error' in locations:
                return Response({"status": "error", "message": locations['error']}, status=400)

            # Step 4: Latest Data Timestamp Retrieval
            latest_waktu = RevenueRealtime.objects.filter(
                id_lokasi__in=locations
            ).aggregate(Max('waktu'))['waktu__max']

            if not latest_waktu:
                return Response({"detail": "No data available"}, status=404)

            # Step 5: Calculate Today's Revenue and Transactions
            # These numbers automatically update when new transactions occur
            today_date = latest_waktu.date() 
            pendapatan_hari_ini = RevenueRealtime.objects.filter(
                tanggal=today_date,
                waktu__lte=latest_waktu,
                id_lokasi__in=locations
            ).aggregate(total=Sum('jumlah'))['total'] or 0

            # Calculate today's total transactions (qty)
            transaksi_hari_ini = RevenueRealtime.objects.filter(
                tanggal=today_date,
                waktu__lte=latest_waktu,
                id_lokasi__in=locations
            ).aggregate(total=Sum('qty'))['total'] or 0

            # Step 6: Define Date Range for Historical Data (excluding today)
            end_date = latest_waktu.date() - timedelta(days=1)  # Yesterday
            start_date = end_date - timedelta(days=5)  # Previous 6 days

            # Step 7: Process Historical Data for Previous 6 Days
            historical_pendapatan = 0
            historical_transaksi = 0

            # loop for historical data
            for single_date in (start_date + timedelta(n) for n in range(6)):  # 6 days, excluding today
                # Fetch parking revenue data
                parkir_day = IncomeParkir.objects.filter(
                    id_lokasi__in=locations,
                    tanggal=single_date
                ).aggregate(
                    cash=Sum('cash'),
                    prepaid=Sum('prepaid'),
                    casual=Sum('casual'),
                    pass_field=Sum('pass_field')
                )

                # Fetch membership revenue data
                member_day = IncomeMember.objects.filter(
                    id_lokasi__in=locations,
                    tanggal=single_date
                ).aggregate(member=Sum('member'))

                # Fetch manual transaction data
                manual_day = IncomeManual.objects.filter(
                    id_lokasi__in=locations,
                    tanggal=single_date
                ).aggregate(
                    manual=Sum('manual'),
                    masalah=Sum('masalah')
                )

                # Calculate daily revenue
                daily_revenue = (
                    Decimal(parkir_day['cash'] or 0) +
                    Decimal(parkir_day['prepaid'] or 0) +
                    Decimal(manual_day['manual'] or 0) +
                    Decimal(member_day['member'] or 0) -
                    Decimal(manual_day['masalah'] or 0)
                )

                # Calculate daily transactions
                daily_transactions = (
                    Decimal(parkir_day['casual'] or 0) +
                    Decimal(parkir_day['pass_field'] or 0)
                )

                historical_pendapatan += daily_revenue
                historical_transaksi += daily_transactions

            # Step 8: Calculate Total Numbers
            # These totals automatically update as they include the dynamic today's numbers
            total_pendapatan = historical_pendapatan + pendapatan_hari_ini
            total_transaksi = historical_transaksi + transaksi_hari_ini

            # Step 9: Prepare Final Summary Data
            summary_data = {
                "total_pendapatan": int(total_pendapatan),
                "pendapatan_hari_ini": int(pendapatan_hari_ini),
                "total_transaksi": int(total_transaksi),
                "transaksi_hari_ini": int(transaksi_hari_ini),
                "waktu": latest_waktu,
            }

            # Step 10: Serialize and Return Response
            serializer = SummaryCardsSerializer(summary_data)
            return Response(serializer.data)

        except Exception as e:
            return Response({
                "status": "error", 
                "message": f"An error occurred: {str(e)}"
            }, status=500)